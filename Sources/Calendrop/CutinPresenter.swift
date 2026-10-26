import AppKit
import CalendropCore
import SwiftUI

/// Puts the cut-in in front of the user until they join or dismiss it.
///
/// Full screen, it is one window per `NSScreen`. Whenever the set of screens or their
/// frames change — a display unplugged, a resolution switched, the lid closed — the
/// windows are rebuilt to match, so no screen is ever left uncovered or half-covered.
/// Compact, it is one panel per screen that never takes focus
/// from the call; hidden, it holds the meetings with nothing on screen.
@MainActor
final class CutinPresenter {
  var onJoin: ((Meeting) -> Void)?
  var onDismiss: (() -> Void)?

  private(set) var meetings: [Meeting] = []
  private(set) var presentation = CutinPresentation.fullScreen
  var theme = CutinPreset.allCases[0].theme {
    didSet { if theme != oldValue, isShowing { rebuild() } }
  }
  var accounts: [AccountSettings] = [] {
    didSet { if accounts != oldValue, isShowing { rebuild() } }
  }
  /// Whether a cut-in that was not on screen in its current form slides in.
  var dropsIn = true
  var compactPosition = CompactPosition.top {
    didSet { if compactPosition != oldValue, presentation == .compact, isShowing { rebuild() } }
  }
  private(set) var windows: [NSWindow] = []
  private let screens: () -> [NSScreen]
  /// The screens the windows were built for, to notice when they change.
  private var screenFrames: [CGRect] = []
  private var observers: [NSObjectProtocol] = []
  private var keyMonitor: Any?

  /// Whether a cut-in holds meetings, on screen or not.
  var isShowing: Bool { !meetings.isEmpty }
  private var isCovering: Bool { isShowing && presentation == .fullScreen }

  init(screens: @escaping () -> [NSScreen] = { NSScreen.screens }) {
    self.screens = screens
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      let keyCode = event.keyCode
      let modifiers = EmergencyKey.Modifiers(rawValue: event.modifierFlags.rawValue)
      let dismissed = MainActor.assumeIsolated { () -> Bool in
        guard let self, self.isCovering, EmergencyKey.matches(keyCode: keyCode, modifiers: modifiers) else {
          return false
        }
        self.onDismiss?()
        return true
      }
      return dismissed ? nil : event
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.syncWithScreens(force: true) }
      })
    observers.append(
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.bringToFront() }
      })
  }

  func show(_ meetings: [Meeting], as presentation: CutinPresentation = .fullScreen) {
    let entering = windows.isEmpty || presentation != self.presentation
    // Compares whole meetings, not only their IDs: a held-back meeting follows the
    // calendar, and a moved end or a new link must reach the card's join button.
    let changed = meetings != self.meetings || presentation != self.presentation
    self.meetings = meetings
    self.presentation = presentation
    if changed || (windows.isEmpty && presentation != .hidden) {
      rebuild(dropsIn: entering && dropsIn)
    }
  }

  func hide() {
    meetings = []
    presentation = .fullScreen
    for window in windows { window.orderOut(nil) }
    windows = []
  }

  /// Called on every tick as well as on screen notifications: macOS sometimes posts
  /// the notification before `NSScreen.screens` settles, and the tick catches that.
  func syncWithScreens(force: Bool) {
    guard isShowing else { return }
    if force || screens().map(\.frame) != screenFrames {
      rebuild()
    } else {
      bringToFront()
    }
  }

  /// Only a cut-in that was not on screen in this form slides in; rebuilding one
  /// already there, for a display or style change, must not replay the entrance.
  private func rebuild(dropsIn: Bool = false) {
    for window in windows { window.orderOut(nil) }
    let screens = screens()
    screenFrames = screens.map(\.frame)
    switch presentation {
    case .fullScreen:
      windows = screens.map { makeWindow(for: $0, dropsIn: dropsIn) }
      bringToFront()
    case .compact:
      let panels = screens.map { makePanel(on: $0, slidesIn: dropsIn) }
      windows = panels.map { $0.0 }
      bringToFront()
      if dropsIn {
        for (panel, settled) in panels { slide(panel, to: settled) }
      }
    case .hidden:
      windows = []
    }
  }

  /// A compact panel comes forward without activating Calendrop, so the call keeps
  /// the keyboard.
  private func bringToFront() {
    guard isShowing else { return }
    guard presentation == .fullScreen else {
      for window in windows { window.orderFrontRegardless() }
      return
    }
    if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
    for window in windows { window.orderFrontRegardless() }
    let key = windows.first { $0.screen == NSScreen.main } ?? windows.first
    if let key, !key.isKeyWindow { key.makeKey() }
  }

  private func makeWindow(for screen: NSScreen, dropsIn: Bool) -> NSWindow {
    let window = CutinWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    configure(window)
    window.contentView = NSHostingView(
      rootView: CutinView(
        meetings: meetings,
        theme: theme,
        accounts: accounts,
        dropsIn: dropsIn,
        onJoin: { [weak self] in self?.onJoin?($0) },
        onDismiss: { [weak self] in self?.onDismiss?() }
      ))
    window.setFrame(screen.frame, display: true)
    return window
  }

  /// The panel starts past the screen edge when it slides in, and the frame it
  /// settles at is returned alongside.
  private func makePanel(on screen: NSScreen, slidesIn: Bool) -> (NSWindow, CGRect) {
    let panel = CompactCutinPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    configure(panel)
    // A panel hides whenever Calendrop is deactivated by default; this one must stay
    // while the user works in the call app.
    panel.hidesOnDeactivate = false
    let host = FirstMouseHostingView(
      rootView: CompactCutinView(
        meetings: meetings,
        theme: theme,
        accounts: accounts,
        onJoin: { [weak self] in self?.onJoin?($0) },
        onDismiss: { [weak self] in self?.onDismiss?() }
      ))
    panel.contentView = host
    var size = host.fittingSize
    // The card already pads itself to leave room for its shadow.
    let margin: CGFloat = 4
    let available = screen.visibleFrame.height - margin * 2
    if size.height > available {
      host.rootView.height = available
      size.height = available
    }
    let settled = compactPosition.frame(of: size, in: screen.visibleFrame, margin: margin)
    if slidesIn && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      panel.alphaValue = 0
      panel.setFrame(settled, display: true)
    } else if slidesIn {
      panel.setFrame(
        compactPosition.entranceFrame(of: size, in: screen.visibleFrame, screen: screen.frame, margin: margin),
        display: true)
    } else {
      panel.setFrame(settled, display: true)
    }
    return (panel, settled)
  }

  /// Springs past the settled frame a little, like the full-screen drop-in; with Reduce
  /// Motion on, fades in where it settles instead.
  private func slide(_ panel: NSWindow, to settled: CGRect) {
    NSAnimationContext.runAnimationGroup { context in
      if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        context.duration = 0.25
        panel.animator().alphaValue = 1
      } else {
        context.duration = 0.5
        context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.4, 0.64, 1)
        panel.animator().setFrame(settled, display: true)
      }
    }
  }

  private func configure(_ window: NSWindow) {
    window.isReleasedWhenClosed = false
    // Above full-screen apps, the Dock and the menu bar.
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isMovable = false
  }
}

private final class CutinWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
  // Escape and ⌘W must not close the cut-in; only the on-screen controls and the
  // emergency key combination do.
  override func cancelOperation(_ sender: Any?) {}
  override func performClose(_ sender: Any?) {}
}

/// Never key: typing stays with the call the user is in.
private final class CompactCutinPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// The panel is never key, so a click must act on the first press rather than only
/// bring the window forward.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
