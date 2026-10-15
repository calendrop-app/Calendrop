import AppKit
import CalendropCore
import SwiftUI

/// Covers every screen with the cut-in until the user joins or dismisses it.
///
/// One window per `NSScreen`. Whenever the set of screens or their frames change —
/// a display unplugged, a resolution switched, the lid closed — the windows are
/// rebuilt to match, so no screen is ever left uncovered or half-covered.
@MainActor
final class CutinPresenter {
  var onJoin: ((Meeting) -> Void)?
  var onDismiss: (() -> Void)?

  private(set) var meetings: [Meeting] = []
  var theme = CutinPreset.allCases[0].theme {
    didSet { if theme != oldValue, isShowing { rebuild() } }
  }
  var accounts: [AccountSettings] = [] {
    didSet { if accounts != oldValue, isShowing { rebuild() } }
  }
  /// Whether a cut-in that was not on screen falls in from the top.
  var dropsIn = true
  private var windows: [NSWindow] = []
  private var observers: [NSObjectProtocol] = []

  var isShowing: Bool { !meetings.isEmpty }

  init() {
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

  func show(_ meetings: [Meeting]) {
    let changed = meetings.map(\.id) != self.meetings.map(\.id)
    let arriving = windows.isEmpty
    self.meetings = meetings
    if changed || arriving { rebuild(dropsIn: arriving && dropsIn) }
  }

  func hide() {
    meetings = []
    for window in windows { window.orderOut(nil) }
    windows = []
  }

  /// Called on every tick as well as on screen notifications: macOS sometimes posts
  /// the notification before `NSScreen.screens` settles, and the tick catches that.
  func syncWithScreens(force: Bool) {
    guard isShowing else { return }
    let screenFrames = NSScreen.screens.map(\.frame)
    if force || screenFrames != windows.map(\.frame) {
      rebuild()
    } else {
      bringToFront()
    }
  }

  /// Only a cut-in that was not on screen drops in; rebuilding one already showing,
  /// for a display or style change, must not replay the entrance.
  private func rebuild(dropsIn: Bool = false) {
    for window in windows { window.orderOut(nil) }
    windows = NSScreen.screens.map { makeWindow(for: $0, dropsIn: dropsIn) }
    bringToFront()
  }

  private func bringToFront() {
    guard isShowing else { return }
    if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
    for window in windows { window.orderFrontRegardless() }
    let key = windows.first { $0.screen == NSScreen.main } ?? windows.first
    if let key, !key.isKeyWindow { key.makeKey() }
  }

  private func makeWindow(for screen: NSScreen, dropsIn: Bool) -> NSWindow {
    let window = CutinWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    // Above full-screen apps, the Dock and the menu bar.
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isMovable = false
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
}

private final class CutinWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
  // Escape and ⌘W must not close the cut-in; only the on-screen controls do.
  override func cancelOperation(_ sender: Any?) {}
  override func performClose(_ sender: Any?) {}
}
