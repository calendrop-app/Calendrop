import AppKit
import CalendropCore

@MainActor
protocol StatusBarActions: AnyObject {
  func join(_ meeting: Meeting)
  func refreshNow()
  func tryDemo(_ scenario: DemoCalendar.Scenario)
  func previewCutin()
  func openSettings()
  func signIn(hint: String?)
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let model: AppModel
  private weak var actions: StatusBarActions?
  private static let titleLength = 24

  init(model: AppModel, actions: StatusBarActions) {
    self.model = model
    self.actions = actions
    super.init()
    item.button?.imagePosition = .imageLeading
    let menu = NSMenu()
    menu.delegate = self
    item.menu = menu
    updateTitle(now: Date())
  }

  func updateTitle(now: Date) {
    guard let button = item.button else { return }
    let symbol = model.needsAttention ? "calendar.badge.exclamationmark" : "calendar"
    if button.image?.accessibilityDescription != symbol {
      button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
    }
    if let next = model.policy.nextMeeting(in: model.meetings, now: now) {
      let title = Countdown.truncate(next.title, to: Self.titleLength)
      button.title = " \(title) · \(Countdown.short(next.start.timeIntervalSince(now)))"
    } else {
      button.title = ""
    }
  }

  // MARK: NSMenuDelegate

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    let now = Date()

    if model.isDemo {
      let banner = NSMenuItem(title: "Demo Mode — sample meetings only", action: nil, keyEquivalent: "")
      banner.image = NSImage(systemSymbolName: "theatermasks", accessibilityDescription: nil)
      banner.isEnabled = false
      menu.addItem(banner)
      let tryItem = NSMenuItem(title: "Try Cut-in", action: nil, keyEquivalent: "")
      let scenarios = NSMenu()
      for scenario in DemoCalendar.Scenario.allCases {
        let item = action(scenario.title, #selector(tryDemo(_:)))
        item.representedObject = scenario.rawValue
        scenarios.addItem(item)
      }
      tryItem.submenu = scenarios
      menu.addItem(tryItem)
      menu.addItem(.separator())
    } else if model.config.oauthClient == nil {
      menu.addItem(action("Set Up Google OAuth Client…", #selector(openSettings)))
      menu.addItem(.separator())
    } else if model.config.accounts.isEmpty {
      menu.addItem(action("Add Google Account…", #selector(addAccount)))
      menu.addItem(.separator())
    }

    var needsSeparator = false
    for account in model.config.accounts {
      switch model.state(of: account) {
      case .ok:
        continue
      case .needsSignIn:
        let item = action("Sign In to \(account)…", #selector(signIn(_:)))
        item.representedObject = account
        item.image = NSImage(
          systemSymbolName: "person.crop.circle.badge.exclamationmark", accessibilityDescription: nil)
        menu.addItem(item)
      case .error(let message):
        let item = NSMenuItem(
          title: "\(account): \(Countdown.truncate(message, to: 60))", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        item.isEnabled = false
        menu.addItem(item)
      }
      needsSeparator = true
    }
    if needsSeparator { menu.addItem(.separator()) }

    addMeetings(to: menu, now: now)

    menu.addItem(.separator())
    if !model.isDemo {
      menu.addItem(action("Refresh Now", #selector(refreshNow), key: "r"))
      menu.addItem(action("Preview Cut-in", #selector(previewCutin)))
    }
    menu.addItem(action("Settings…", #selector(openSettings), key: ","))
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(title: "Quit Calendrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
  }

  private func addMeetings(to menu: NSMenu, now: Date) {
    let upcoming = model.meetings.filter { $0.end > now }
    guard !upcoming.isEmpty else {
      let empty = NSMenuItem(title: "No upcoming meetings", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
      return
    }
    let calendar = Calendar.current
    let byDay = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.start) }
    for day in byDay.keys.sorted() {
      let header =
        calendar.isDateInToday(day)
        ? "Today" : calendar.isDateInTomorrow(day) ? "Tomorrow" : day.formatted(date: .abbreviated, time: .omitted)
      menu.addItem(.sectionHeader(title: header))
      for meeting in byDay[day]! {
        menu.addItem(menuItem(for: meeting, now: now))
      }
    }
  }

  private func menuItem(for meeting: Meeting, now: Date) -> NSMenuItem {
    let time = meeting.start.formatted(.dateTime.hour().minute())
    let ongoing = meeting.start <= now
    let item = NSMenuItem(
      title: "\(time)  \(Countdown.truncate(meeting.title, to: 48))", action: #selector(join(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = meeting
    item.image = NSImage(
      systemSymbolName: meeting.joinURL != nil ? (ongoing ? "video.fill" : "video") : "calendar",
      accessibilityDescription: nil)
    if #available(macOS 14.4, *) {
      item.subtitle = meeting.account
    }
    item.toolTip = meeting.joinURL?.absoluteString ?? "Open in Google Calendar"
    item.state = ongoing ? .mixed : .off
    return item
  }

  private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
    let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
    item.target = self
    return item
  }

  // MARK: Actions

  @objc private func join(_ sender: NSMenuItem) {
    guard let meeting = sender.representedObject as? Meeting else { return }
    actions?.join(meeting)
  }

  @objc private func signIn(_ sender: NSMenuItem) {
    actions?.signIn(hint: sender.representedObject as? String)
  }

  @objc private func addAccount() { actions?.signIn(hint: nil) }
  @objc private func refreshNow() { actions?.refreshNow() }
  @objc private func tryDemo(_ sender: NSMenuItem) {
    guard let raw = sender.representedObject as? String, let scenario = DemoCalendar.Scenario(rawValue: raw) else {
      return
    }
    actions?.tryDemo(scenario)
  }
  @objc private func previewCutin() { actions?.previewCutin() }
  @objc private func openSettings() { actions?.openSettings() }
}
