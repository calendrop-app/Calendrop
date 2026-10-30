import AppKit
import CalendropCore
import Combine
import SwiftUI

@MainActor
protocol StatusBarActions: AnyObject {
  func join(_ meeting: Meeting)
  func openSettings()
  func signIn(hint: String?)
  func refreshNow()
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let model: AppModel
  private weak var actions: StatusBarActions?
  /// "Wed, Oct 21", in the language of the rest of the menu.
  private static let dayFormat = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
  /// The calendar at the top of the open menu, when the settings ask for one.
  private var calendar: (state: MenuCalendarState, item: NSMenuItem)?
  private var calendarUpdates: Set<AnyCancellable> = []

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
    let description = model.needsAttention ? String(localized: "Calendrop, needs attention") : "Calendrop"
    if button.image?.accessibilityDescription != description {
      button.image = Self.icon(attention: model.needsAttention, description: description)
    }
    let label = MenuBarLabel.text(
      meeting: model.policy.nextMeeting(in: model.meetings, now: now),
      now: now, showTitle: model.config.showMeetingTitleInMenuBar)
    button.title = label.map { " \($0)" } ?? ""
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
      menu.addItem(action(String(localized: "Add Google Account…"), #selector(addAccount)))
      menu.addItem(.separator())
    }

    var needsSeparator = false
    for account in model.config.accounts.map(\.email) {
      switch model.state(of: account) {
      case .ok:
        continue
      case .needsSignIn:
        let item = action(String(localized: "Sign In to \(account)…"), #selector(signIn(_:)))
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

    if let span = model.config.menuCalendar.span {
      addCalendar(span, to: menu, now: now)
    } else {
      calendar = nil
      addMeetings(to: menu, now: now)
    }
    addFooter(to: menu, now: now)
  }

  func menuDidClose(_ menu: NSMenu) {
    calendarUpdates.removeAll()
    calendar = nil
    model.endPeriodRead()
  }

  // MARK: Calendar

  /// The calendar, opened on today, and the selected day's meetings under it.
  private func addCalendar(_ span: MenuCalendar.Span, to menu: NSMenu, now: Date) {
    let state = MenuCalendarState(calendar: MenuCalendar(span: span), today: now)
    let hosting = NSHostingView(rootView: MenuCalendarView(state: state))
    hosting.frame.size = NSSize(width: max(hosting.fittingSize.width, 280), height: hosting.fittingSize.height)
    hosting.autoresizingMask = [.width]
    let item = NSMenuItem()
    item.view = hosting
    menu.addItem(item)
    calendar = (state, item)
    addSelectedDay(to: menu, now: now)
    updateColours(now: now)

    // Delivered through the main queue, which runs while the menu tracks the mouse;
    // the main run loop's default mode does not.
    calendarUpdates.removeAll()
    state.$selection.dropFirst().receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.selectionChanged() }
      .store(in: &calendarUpdates)
    model.$periodRead.combineLatest(model.$isReadingPeriod, model.$meetings).dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        let now = Date()
        self?.updateColours(now: now)
        self?.replaceSelectedDay(now: now)
      }
      .store(in: &calendarUpdates)
    model.readPeriod(state.calendar.interval(showing: state.selection))
  }

  private func selectionChanged() {
    guard let state = calendar?.state else { return }
    let interval = state.calendar.interval(showing: state.selection)
    if model.periodRead?.interval != interval {
      model.readPeriod(interval)
    }
    let now = Date()
    updateColours(now: now)
    replaceSelectedDay(now: now)
  }

  private func meetings(on day: Date, in state: MenuCalendarState, now: Date) -> [Meeting]? {
    state.calendar.meetings(
      on: day, refreshed: model.meetings, window: ReadWindow(now: now), period: model.periodRead)
  }

  private func updateColours(now: Date) {
    guard let state = calendar?.state else { return }
    var colours: [Date: [Color]] = [:]
    for day in state.days {
      guard let meetings = meetings(on: day, in: state, now: now) else { continue }
      let accounts = Set(meetings.map(\.account))
      colours[day] = model.config.accounts.filter { accounts.contains($0.email) }.map { Color($0.color) }
    }
    state.colours = colours
  }

  /// The selected day's meetings, all of them, ended ones included, as a calendar lists a day.
  private func addSelectedDay(to menu: NSMenu, now: Date) {
    guard let state = calendar?.state else { return }
    menu.addItem(.separator())
    menu.addItem(.sectionHeader(title: dayTitle(state.selection)))
    guard let meetings = meetings(on: state.selection, in: state, now: now) else {
      let title =
        model.isReadingPeriod ? String(localized: "Loading…") : String(localized: "Could not read this day's meetings")
      let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
      return
    }
    guard !meetings.isEmpty else {
      let empty = NSMenuItem(title: String(localized: "No meetings"), action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
      return
    }
    for meeting in meetings {
      menu.addItem(menuItem(for: meeting, now: now))
    }
  }

  /// Rebuilds everything under the calendar while the menu stays open; the calendar
  /// item itself stays, so the click that changed the day is not cut short.
  private func replaceSelectedDay(now: Date) {
    guard let item = calendar?.item, let menu = item.menu else { return }
    let index = menu.index(of: item)
    while menu.numberOfItems > index + 1 {
      menu.removeItem(at: index + 1)
    }
    addSelectedDay(to: menu, now: now)
    addFooter(to: menu, now: now)
  }

  private func dayTitle(_ day: Date) -> String {
    let calendar = Calendar.current
    return calendar.isDateInToday(day)
      ? String(localized: "Today")
      : calendar.isDateInTomorrow(day) ? String(localized: "Tomorrow") : day.formatted(Self.dayFormat)
  }

  /// How current the meetings are, then settings and quitting.
  private func addFooter(to menu: NSMenu, now: Date) {
    menu.addItem(.separator())
    if !model.config.accounts.isEmpty {
      addSyncStatus(to: menu, now: now)
      menu.addItem(.separator())
    }
    menu.addItem(action(String(localized: "Settings…"), #selector(openSettings), key: ","))
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: String(localized: "Quit Calendrop"), action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
  }

  private func addMeetings(to menu: NSMenu, now: Date) {
    let upcoming = model.meetings.filter { $0.end > now }
    guard !upcoming.isEmpty else {
      let empty = NSMenuItem(
        title: String(localized: "No more meetings today or tomorrow"), action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
      addLookahead(to: menu, now: now)
      return
    }
    let calendar = Calendar.current
    let byDay = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.start) }
    for day in byDay.keys.sorted() {
      menu.addItem(.sectionHeader(title: dayTitle(day)))
      for meeting in byDay[day]! {
        menu.addItem(menuItem(for: meeting, now: now))
      }
    }
  }

  /// The next meeting past tomorrow, or how far ahead nothing was found.
  private func addLookahead(to menu: NSMenu, now: Date) {
    guard let lookahead = model.lookahead else { return }
    if let next = lookahead.next {
      let day = next.start.formatted(Self.dayFormat)
      menu.addItem(.sectionHeader(title: String(localized: "Next · \(day)")))
      menu.addItem(menuItem(for: next, now: now))
    } else {
      let day = lookahead.lastDay.formatted(Self.dayFormat)
      let none = NSMenuItem(
        title: String(localized: "Nothing scheduled through \(day)"), action: nil, keyEquivalent: "")
      none.isEnabled = false
      menu.addItem(none)
    }
  }

  private func addSyncStatus(to menu: NSMenu, now: Date) {
    let title =
      model.isRefreshing
      ? String(localized: "Updating…")
      : SyncStatus.summary(calendars: model.calendarsRead, readAt: model.lastReadAt, now: now)
    let status = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    status.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
    status.isEnabled = false
    menu.addItem(status)
    menu.addItem(action(String(localized: "Refresh Now"), #selector(refreshNow), key: "r"))
  }

  private func menuItem(for meeting: Meeting, now: Date) -> NSMenuItem {
    let time = meeting.start.formatted(.dateTime.hour().minute())
    let ongoing = meeting.start <= now
    let item = NSMenuItem(
      title: "\(time)  \(Countdown.truncate(meeting.title, to: 48))", action: nil, keyEquivalent: "")
    let account = model.config.account(meeting.account)
    let colour = account.map { NSColor($0.color) } ?? .secondaryLabelColor
    // The symbol says whether there is something to join; its fill, whether the user
    // accepted; its colour, whose meeting it is. That a meeting is under way is the
    // item's state mark.
    let shape = meeting.joinURL != nil ? "video" : "calendar.circle"
    item.image = symbol(meeting.response == .accepted ? "\(shape).fill" : shape, colour: colour)
    if #available(macOS 14.4, *) {
      item.subtitle =
        ([meeting.response.label(), account?.displayName ?? meeting.account, meeting.calendarName] as [String?])
        .compactMap { $0 }.joined(separator: " · ")
    }
    item.state = ongoing ? .mixed : .off
    item.submenu = detailMenu(for: meeting, accountName: account?.displayName ?? meeting.account, colour: colour)
    // Clicking the meeting itself does what its submenu offers first.
    item.target = self
    item.representedObject = meeting
    item.action = meeting.joinURL != nil ? #selector(join(_:)) : #selector(openEvent(_:))
    return item
  }

  /// The meeting's actions, then what the event says about itself.
  private func detailMenu(for meeting: Meeting, accountName: String, colour: NSColor) -> NSMenu {
    let menu = NSMenu()
    // Detail lines carry no action but should read as text, not as disabled items.
    menu.autoenablesItems = false

    if meeting.joinURL != nil {
      let join = action(String(localized: "Join Meeting"), #selector(join(_:)))
      join.representedObject = meeting
      join.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)
      menu.addItem(join)
      let copy = action(String(localized: "Copy Meeting Link"), #selector(copyLink(_:)))
      copy.representedObject = meeting
      copy.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
      menu.addItem(copy)
    }
    if meeting.eventURL != nil {
      let open = action(String(localized: "Open in Google Calendar"), #selector(openEvent(_:)))
      open.representedObject = meeting
      open.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
      menu.addItem(open)
    }
    menu.addItem(.separator())

    let span = meeting.end.timeIntervalSince(meeting.start)
    let range =
      "\(meeting.start.formatted(.dateTime.hour().minute())) – \(meeting.end.formatted(.dateTime.hour().minute()))"
    menu.addItem(detail("\(range)  (\(String(localized: "\(Int(span / 60)) min")))", symbol: "clock"))
    let owner = detail("\(accountName) · \(meeting.calendarName)", symbol: "circle.fill")
    owner.image = symbol("circle.fill", colour: colour)
    menu.addItem(owner)
    if let response = meeting.response.label() {
      menu.addItem(detail(response, symbol: "questionmark.circle"))
    }
    if let location = meeting.location {
      menu.addItem(detail(location, symbol: "mappin.and.ellipse"))
    }
    if let organizer = meeting.organizer {
      menu.addItem(detail(String(localized: "Organized by \(organizer)"), symbol: "person.crop.circle"))
    }
    if let people = meeting.attendeeSummary() {
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

  /// The Calendrop symbol as a template image, with a dot cut into its corner
  /// when something needs attention.
  private static func icon(attention: Bool, description: String) -> NSImage? {
    // Outside the app bundle (`swift run`) there is no MenuBarIcon resource.
    guard let base = NSImage(named: "MenuBarIcon") else {
      let name = attention ? "calendar.badge.exclamationmark" : "calendar"
      return NSImage(systemSymbolName: name, accessibilityDescription: description)
    }
    let size = NSSize(width: 16, height: 16)
    let image = NSImage(size: size, flipped: false) { rect in
      base.draw(in: rect)
      if attention {
        let dot = NSRect(x: 10.5, y: 10.5, width: 5.5, height: 5.5)
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dot).fill()
      }
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = description
    return image
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

  @objc private func refreshNow() {
    actions?.refreshNow()
  }

  @objc private func signIn(_ sender: NSMenuItem) {
    actions?.signIn(hint: sender.representedObject as? String)
  }

  @objc private func addAccount() { actions?.signIn(hint: nil) }
  @objc private func openSettings() { actions?.openSettings() }
}
