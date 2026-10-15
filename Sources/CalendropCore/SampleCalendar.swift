import Foundation

/// Sample accounts, calendars and meetings: what a build without Google sign-in
/// shows, and what the appearance settings try the cut-in with.
///
/// Scenarios are laid out so they are due at once.
public enum SampleCalendar {
  public static let accounts = ["work@example.com", "personal@example.com"]
  /// The accounts a sample setup starts with, as a real one would already have them.
  public static let presetAccounts: [(email: String, label: String?)] = [
    (accounts[0], "Work"), (accounts[1], "Personal"),
  ]

  public enum Scenario: String, CaseIterable, Sendable {
    case single
    case simultaneous
    case closeTogether
    case withoutLink

    public var title: String {
      switch self {
      case .single: "Single Meeting"
      case .simultaneous: "Meetings at the Same Time"
      case .closeTogether: "Meetings Close Together"
      case .withoutLink: "Meeting Without a Video Link"
      }
    }

    public func meetings(now: Date, leadTime: TimeInterval) -> [Meeting] {
      let start = now.addingTimeInterval(leadTime)
      let work = accounts[0]
      let personal = accounts[1]
      let entries: [Entry] =
        switch self {
        case .single:
          [
            Entry("weekly-sync", "Weekly sync", start, 30, work, "work").with(
              notes: "Status of each workstream, then risks and asks.\nNotes: https://example.com/sample/notes",
              organizer: "Mika Tanaka", attendees: ["Mika Tanaka", "Ken Sato", "Aki Mori", "Lee Chen", "Rin Ito"])
          ]
        case .simultaneous:
          [
            Entry("product-review", "Product review", start, 60, work, "work"),
            Entry("interview", "採用面接（エンジニア）", start, 30, personal, "personal"),
          ]
        case .closeTogether:
          [
            Entry("check-in", "Quick check-in", start, 4, work, "work"),
            Entry(
              "design-review", "デザインレビュー（モバイルアプリ リニューアル）", start.addingTimeInterval(5 * minute), 30,
              personal, "personal"),
          ]
        case .withoutLink:
          [
            Entry("room-meeting", "Planning in Room 3A", start, 30, work, "work", joins: false).with(
              location: "Room 3A, 4th floor", notes: "Bring the printed roadmap.", attendees: ["Ken Sato", "Aki Mori"])
          ]
        }
      // A fresh UID per run, so a scenario tried again is never already acknowledged.
      let run = Int(now.timeIntervalSince1970)
      return Meeting.merge([entries.map { $0.meeting(uidPrefix: "sample-scenario-\(rawValue)-\(run)-") }])
    }
  }

  /// The calendars a sample account offers, some of them unticked in "Google Calendar".
  public static func calendars(for account: String) -> [CalendarRef] {
    let entries: [(String, String, Bool)] =
      switch account {
      case accounts[0]:
        [("work", "Work", true), ("apollo", "Project Apollo", true), ("team-holidays", "Team holidays", false)]
      case accounts[1]:
        [("personal", "Personal", true), ("family", "Family", true), ("birthdays", "Birthdays", false)]
      default:
        [("main", "Calendar", true), ("shared", "Shared with me", false)]
      }
    return entries.map { CalendarRef(id: calendarID(account, $0.0), name: $0.1, isSelectedInGoogle: $0.2) }
  }

  /// The address the next sample sign-in yields: the named sample accounts first.
  public static func newAccount(existing: [String]) -> String {
    let numbered = (1...).lazy.map { "sample\($0)@example.com" }
    return accounts.first { !existing.contains($0) } ?? numbered.first { !existing.contains($0) }!
  }

  /// Every sample meeting of `accounts`, on all of their calendars; which calendars
  /// count is up to the account's settings, as with real accounts.
  public static func meetings(now: Date, accounts: [String]) -> [Meeting] {
    Meeting.merge([accounts.flatMap { schedule(for: $0, now: now) }.map { $0.meeting(uidPrefix: "sample-") }])
  }

  private static func schedule(for account: String, now: Date) -> [Entry] {
    func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * minute) }
    switch account {
    case accounts[0]:
      return [
        Entry("all-hands", "All-hands (in progress)", at(-20), 45, account, "work"),
        Entry("standup", "Daily standup", at(30), 15, account, "work").with(
          notes: "Yesterday, today, blockers. Keep it under 15 minutes.", organizer: "Mika Tanaka",
          attendees: ["Mika Tanaka", "Ken Sato", "Aki Mori", "Lee Chen"]),
        Entry("apollo-sync", "Apollo sync", at(90), 30, account, "apollo"),
        Entry("planning", "Sprint planning", at(150), 60, account, "work").with(
          location: "Room 3A / online",
          notes: "1. Review last sprint\n2. Pick stories for the next one\nBoard: https://example.com/sample/board",
          organizer: "Mika Tanaka", attendees: ["Mika Tanaka", "Ken Sato", "Aki Mori"]),
        Entry("holiday-party", "Holiday party", at(300), 120, account, "team-holidays", joins: false),
      ]
    case accounts[1]:
      return [
        Entry("lunch", "Lunch with Aki", at(60), 60, account, "personal", joins: false).with(
          location: "Cafe Komorebi, 2F", attendees: ["Aki Mori"]),
        Entry("school", "School pickup", at(240), 30, account, "family", joins: false),
        Entry("birthday", "Mom's birthday call", at(360), 30, account, "birthdays"),
        Entry("customer", "Customer call", at(24 * 60), 30, account, "personal"),
      ]
    default:
      return [
        Entry("intro", "Intro call", at(75), 30, account, "main"),
        Entry("shared-review", "Shared review", at(200), 45, account, "shared"),
      ]
    }
  }

  private static func calendarID(_ account: String, _ slug: String) -> String { "\(account)/\(slug)" }

  private static let minute: TimeInterval = 60

  private struct Entry {
    var slug: String
    var title: String
    var start: Date
    var minutes: Double
    var account: String
    var calendar: String
    var joins: Bool
    var location: String?
    var notes: String?
    var organizer: String?
    var attendees: [String] = []

    init(
      _ slug: String, _ title: String, _ start: Date, _ minutes: Double, _ account: String, _ calendar: String,
      joins: Bool = true
    ) {
      self.slug = slug
      self.title = title
      self.start = start
      self.minutes = minutes
      self.account = account
      self.calendar = calendar
      self.joins = joins
    }

    func with(
      location: String? = nil, notes: String? = nil, organizer: String? = nil, attendees: [String] = []
    ) -> Entry {
      var entry = self
      entry.location = location
      entry.notes = notes
      entry.organizer = organizer
      entry.attendees = attendees
      return entry
    }

    func meeting(uidPrefix: String) -> Meeting {
      let id = SampleCalendar.calendarID(account, calendar)
      return Meeting(
        uid: "\(uidPrefix)\(account)-\(slug)",
        title: title,
        start: start,
        end: start.addingTimeInterval(minutes * SampleCalendar.minute),
        joinURL: joins ? URL(string: "https://example.com/sample/join/\(slug)") : nil,
        htmlLink: URL(string: "https://example.com/sample/event/\(slug)"),
        account: account,
        calendarID: id,
        calendarName: SampleCalendar.calendars(for: account).first { $0.id == id }?.name ?? calendar,
        location: location,
        notes: notes,
        organizer: organizer,
        attendees: attendees
      )
    }
  }
}
