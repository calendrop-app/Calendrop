import AppKit
import CalendropCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusBarActions {
  private let model = AppModel(isDemo: CommandLine.arguments.contains("--demo"))
  private let presenter = CutinPresenter()
  private var statusBar: StatusBarController?
  private var settingsWindow: NSWindow?
  private var timers: [Timer] = []

  private static let refreshInterval: TimeInterval = 3 * 60

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBar = StatusBarController(model: model, actions: self)
    presenter.onJoin = { [weak self] meeting in self?.join(meeting) }
    presenter.onDismiss = { [weak self] in self?.dismissCutin() }

    schedule(every: 1) { $0.tick() }
    schedule(every: Self.refreshInterval) { $0.refreshNow() }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshNow() }
    }

    refreshNow()
  }

  private func schedule(every interval: TimeInterval, _ body: @escaping @MainActor (AppDelegate) -> Void) {
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        if let self { body(self) }
      }
    }
    // .common keeps the countdown ticking while the status menu is open.
    RunLoop.main.add(timer, forMode: .common)
    timers.append(timer)
  }

  private func tick() {
    let now = Date()
    statusBar?.updateTitle(now: now)
    let group = model.policy.cutInGroup(model.cutInCandidates, now: now, acknowledged: model.acknowledged)
    // Once shown, the cut-in stays until the user acts, even past the grace period;
    // newly gathered meetings join the ones already on screen.
    let shownIDs = Set(presenter.meetings.map(\.id))
    let added = group.filter { !shownIDs.contains($0.id) }
    if !added.isEmpty {
      presenter.show((presenter.meetings + added).sorted { $0.start < $1.start })
    }
    presenter.syncWithScreens(force: false)
  }

  private func dismissCutin() {
    model.acknowledge(presenter.meetings)
    presenter.hide()
  }

  // MARK: StatusBarActions

  func join(_ meeting: Meeting) {
    model.acknowledge(model.policy.settledByJoining(meeting, among: presenter.meetings + [meeting]))
    presenter.hide()
    if let url = meeting.openURL {
      NSWorkspace.shared.open(url)
    }
  }

  func refreshNow() {
    Task {
      await model.refresh()
      tick()
    }
  }

  func tryDemo(_ scenario: DemoCalendar.Scenario) {
    presenter.hide()
    model.tryDemo(scenario)
    tick()
  }

  /// Shows a copy of the next meeting under a throwaway UID, so ending the preview
  /// never acknowledges the real meeting and its cut-in still fires.
  func previewCutin() {
    let now = Date()
    let lead = TimeInterval(max(1, model.config.leadMinutes) * 60)
    let next = model.policy.nextMeeting(in: model.meetings, now: now)
    let sample = Meeting(
      uid: "preview-\(UUID().uuidString)",
      title: next?.title ?? "Preview meeting",
      start: now.addingTimeInterval(lead),
      end: now.addingTimeInterval(lead + 1800),
      joinURL: next?.joinURL,
      htmlLink: next?.htmlLink ?? URL(string: "https://calendar.google.com/"),
      account: next?.account ?? model.config.accounts.first ?? "preview@example.com",
      calendarName: "Preview"
    )
    presenter.show([sample])
  }

  func openSettings() {
    if settingsWindow == nil {
      let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
      window.title = "Calendrop Settings"
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      window.setContentSize(NSSize(width: 820, height: 560))
      window.contentMinSize = NSSize(width: 620, height: 420)
      window.isReleasedWhenClosed = false
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }

  func signIn(hint: String?) {
    Task { await model.signIn(hint: hint) }
  }
}
