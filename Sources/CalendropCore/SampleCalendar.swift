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
    case manyScripts

    public var title: String {
      switch self {
      case .single: "Single Meeting"
      case .simultaneous: "Meetings at the Same Time"
      case .closeTogether: "Meetings Close Together"
      case .withoutLink: "Meeting Without a Video Link"
      case .manyScripts: "Titles in Many Scripts"
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
            Entry("interview", "Hiring interview (engineering)", start, 30, personal, "personal"),
          ]
        case .closeTogether:
          [
            Entry("check-in", "Quick check-in", start, 4, work, "work"),
            Entry(
              "design-review", "Design review (mobile app redesign)", start.addingTimeInterval(5 * minute), 30,
              personal, "personal"),
          ]
        case .withoutLink:
          [
            Entry("room-meeting", "Planning in Room 3A", start, 30, work, "work", joins: false).with(
              location: "Room 3A, 4th floor", notes: "Bring the printed roadmap.", attendees: ["Ken Sato", "Aki Mori"])
          ]
        case .manyScripts:
          // Long titles in scripts that break in different ways: CJK glyph choice,
          // Hangul syllables, right-to-left text, combining marks and composed emoji.
          [
            ("ja", "デザインレビュー（モバイルアプリ リニューアル）と次四半期の計画", work),
            ("ko", "모바일 앱 리뉴얼 디자인 리뷰 및 다음 분기 계획 회의", personal),
            ("zh-hans", "移动应用改版设计评审与下季度规划会议", work),
            ("zh-hant", "行動應用程式改版設計審查與下一季規劃會議", personal),
            ("ar", "مراجعة تصميم تطبيق الجوال وخطة الربع القادم", work),
            ("th", "ประชุมทบทวนการออกแบบแอปมือถือและวางแผนไตรมาสหน้า", personal),
            ("hi", "मोबाइल ऐप डिज़ाइन समीक्षा और अगली तिमाही की योजना", work),
            ("emoji", "👨‍👩‍👧‍👦 Family sync 🇯🇵🇰🇷🇨🇳🇹🇼 🏳️‍🌈 👍🏽", personal),
          ].map { slug, title, account in
            Entry("scripts-\(slug)", title, start, 30, account, account == work ? "work" : "personal")
          }
        }
      // A fresh UID per run, so a scenario tried again is never already acknowledged.
      let run = Int(now.timeIntervalSince1970)
      return Meeting.merge([entries.map { $0.meeting(uidPrefix: "sample-scenario-\(rawValue)-\(run)-") }])
    }
  }

  /// The calendars a sample account offers: its main calendar first, whose ID is the
  /// account's address as with a real account, then calendars it can opt into.
  public static func calendars(for account: String) -> [CalendarRef] {
    let entries: [(slug: String, name: String)] =
      switch account {
      case accounts[0]: [("work", "Work"), ("apollo", "Project Apollo"), ("team-holidays", "Team holidays")]
      case accounts[1]: [("personal", "Personal"), ("family", "Family"), ("birthdays", "Birthdays")]
      default: [("main", "Calendar"), ("shared", "Shared with me")]
      }
    return entries.map {
      CalendarRef(id: calendarID(account, $0.slug), name: $0.name, isPrimary: mainSlugs.contains($0.slug))
    }
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
        Entry("apollo-sync", "Apollo sync", at(90), 30, account, "apollo", response: .tentative),
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
        Entry("customer", "Customer call", at(24 * 60), 30, account, "personal", response: .unanswered),
      ]
    default:
      return [
        Entry("intro", "Intro call", at(75), 30, account, "main"),
        Entry("shared-review", "Shared review", at(200), 45, account, "shared"),
      ]
    }
  }

  private static let mainSlugs: Set<String> = ["work", "personal", "main"]

  private static func calendarID(_ account: String, _ slug: String) -> String {
    mainSlugs.contains(slug) ? account : "\(account)/\(slug)"
  }

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
    var response: Meeting.Response

    init(
      _ slug: String, _ title: String, _ start: Date, _ minutes: Double, _ account: String, _ calendar: String,
      joins: Bool = true, response: Meeting.Response = .accepted
    ) {
      self.slug = slug
      self.title = title
      self.start = start
      self.minutes = minutes
      self.account = account
      self.calendar = calendar
      self.joins = joins
      self.response = response
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
        attendees: attendees,
        response: response
      )
    }
  }
}
