import AppKit
import CalendropCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusBarActions {
  private let model = AppDelegate.makeModel()
  private let presenter = CutinPresenter()
  private var statusBar: StatusBarController?
  private var settingsWindow: NSWindow?
  private var timers: [Timer] = []
  /// Whether the cut-in on screen is a trial from the appearance settings.
  private var showingTrial = false

  private static let refreshInterval: TimeInterval = 3 * 60

  /// Real Google accounts when the build carries the OAuth client, sample accounts
  /// otherwise. Sample accounts are kept in memory only, so they neither reach the
  /// settings real accounts share through iCloud nor outlive the app.
  private static func makeModel() -> AppModel {
    if let client = OAuthClient(infoDictionary: Bundle.main.infoDictionary ?? [:]) {
      return AppModel(source: GoogleCalendarSource(client: client), store: ConfigStore(url: ConfigStore.defaultURL()))
    }
    return AppModel(source: SampleCalendarSource(), store: MemoryConfigStore())
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBar = StatusBarController(model: model, actions: self)
    presenter.onJoin = { [weak self] meeting in self?.answerCutin(meeting) }
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
    presenter.theme = model.config.appearance.theme
    presenter.accounts = model.config.accounts
    // A trial shows sample meetings only; real ones wait until it is closed.
    guard !showingTrial else {
      presenter.syncWithScreens(force: false)
      return
    }
    let group = model.policy.cutInGroup(model.meetings, now: now, acknowledged: model.acknowledged)
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
    if !showingTrial { model.acknowledge(presenter.meetings) }
    closeCutin()
  }

  private func closeCutin() {
    showingTrial = false
    presenter.hide()
  }

  // MARK: StatusBarActions

  /// The cut-in's button: joins the meeting, or for one with nothing to join only
  /// acknowledges it, rather than sending the user to the calendar.
  private func answerCutin(_ meeting: Meeting) {
    if showingTrial {
      // Nothing on a trial is a real meeting, so nothing is acknowledged.
      closeCutin()
      if meeting.joinURL != nil, let url = meeting.openURL { NSWorkspace.shared.open(url) }
    } else if meeting.joinURL != nil {
      join(meeting)
    } else {
      model.acknowledge(model.policy.settledByJoining(meeting, among: model.meetings + presenter.meetings))
      closeCutin()
    }
  }

  func join(_ meeting: Meeting) {
    model.acknowledge(model.policy.settledByJoining(meeting, among: model.meetings + presenter.meetings + [meeting]))
    closeCutin()
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

  /// Shows a scenario at once, for judging the cut-in's look; nothing it shows is a real meeting.
  func tryCutin(_ scenario: SampleCalendar.Scenario) {
    showingTrial = true
    presenter.theme = model.config.appearance.theme
    presenter.accounts = model.config.accounts
    presenter.show(scenario.meetings(now: Date(), leadTime: model.policy.leadTime))
  }

  func openSettings() {
    if settingsWindow == nil {
      let window = NSWindow(
        contentViewController: NSHostingController(
          rootView: SettingsView(model: model, onTry: { [weak self] in self?.tryCutin($0) })))
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
