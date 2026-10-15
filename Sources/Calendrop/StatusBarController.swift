import AppKit
import CalendropCore

@MainActor
protocol StatusBarActions: AnyObject {
  func join(_ meeting: Meeting)
  func refreshNow()
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

    if let notice = model.sourceNotice {
      let item = NSMenuItem(title: Countdown.truncate(notice, to: 60), action: nil, keyEquivalent: "")
      item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
      item.toolTip = notice
      item.isEnabled = false
      menu.addItem(item)
      menu.addItem(.separator())
    }
    if model.config.accounts.isEmpty {
      menu.addItem(action("Add Google Account…", #selector(addAccount)))
      menu.addItem(.separator())
    }

    var needsSeparator = false
    for account in model.config.accounts.map(\.email) {
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
    menu.addItem(action("Refresh Now", #selector(refreshNow), key: "r"))
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
      title: "\(time)  \(Countdown.truncate(meeting.title, to: 48))", action: nil, keyEquivalent: "")
    let account = model.config.account(meeting.account)
    let colour = account.map { NSColor($0.color) } ?? .secondaryLabelColor
    // The symbol says whether there is something to join; its colour, whose meeting it is.
    item.image = symbol(meeting.joinURL != nil ? (ongoing ? "video.fill" : "video") : "calendar", colour: colour)
    if #available(macOS 14.4, *) {
      item.subtitle = "\(account?.displayName ?? meeting.account) · \(meeting.calendarName)"
    }
    item.state = ongoing ? .mixed : .off
    item.submenu = detailMenu(for: meeting, accountName: account?.displayName ?? meeting.account, colour: colour)
    return item
  }

  /// The meeting's actions, then what the event says about itself.
  private func detailMenu(for meeting: Meeting, accountName: String, colour: NSColor) -> NSMenu {
    let menu = NSMenu()
    // Detail lines carry no action but should read as text, not as disabled items.
    menu.autoenablesItems = false

    if meeting.joinURL != nil {
      let join = action("Join Meeting", #selector(join(_:)))
      join.representedObject = meeting
      join.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)
      menu.addItem(join)
      let copy = action("Copy Meeting Link", #selector(copyLink(_:)))
      copy.representedObject = meeting
      copy.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
      menu.addItem(copy)
    }
    if meeting.eventURL != nil {
      let open = action("Open in Google Calendar", #selector(openEvent(_:)))
      open.representedObject = meeting
      open.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
      menu.addItem(open)
    }
    menu.addItem(.separator())

    let span = meeting.end.timeIntervalSince(meeting.start)
    let range =
      "\(meeting.start.formatted(.dateTime.hour().minute())) – \(meeting.end.formatted(.dateTime.hour().minute()))"
    menu.addItem(detail("\(range)  (\(Int(span / 60)) min)", symbol: "clock"))
    let owner = detail("\(accountName) · \(meeting.calendarName)", symbol: "circle.fill")
    owner.image = symbol("circle.fill", colour: colour)
    menu.addItem(owner)
    if let location = meeting.location {
      menu.addItem(detail(location, symbol: "mappin.and.ellipse"))
    }
    if let organizer = meeting.organizer {
      menu.addItem(detail("Organized by \(organizer)", symbol: "person.crop.circle"))
    }
    if let people = meeting.attendeeSummary {
      menu.addItem(detail(people, symbol: "person.2"))
    }
    if let notes = meeting.notes {
      menu.addItem(.separator())
      let lines = notes.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
      for (index, line) in lines.prefix(Self.noteLines).enumerated() {
        menu.addItem(detail(line.isEmpty ? " " : line, symbol: index == 0 ? "text.alignleft" : nil))
      }
      if lines.count > Self.noteLines {
        menu.addItem(detail("…", symbol: nil))
      }
    }
    return menu
  }

  private static let noteLines = 8

  private func detail(_ text: String, symbol name: String?) -> NSMenuItem {
    let item = NSMenuItem(title: Countdown.truncate(text, to: 70), action: nil, keyEquivalent: "")
    if text.count > 70 { item.toolTip = text }
    item.image = name.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    return item
  }

  private func symbol(_ name: String, colour: NSColor) -> NSImage? {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(.init(paletteColors: [colour]))
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

  @objc private func copyLink(_ sender: NSMenuItem) {
    guard let url = (sender.representedObject as? Meeting)?.openURL else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(url.absoluteString, forType: .string)
  }

  @objc private func openEvent(_ sender: NSMenuItem) {
    guard let url = (sender.representedObject as? Meeting)?.eventURL else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func signIn(_ sender: NSMenuItem) {
    actions?.signIn(hint: sender.representedObject as? String)
  }

  @objc private func addAccount() { actions?.signIn(hint: nil) }
  @objc private func refreshNow() { actions?.refreshNow() }
  @objc private func openSettings() { actions?.openSettings() }
}
