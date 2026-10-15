import Foundation

/// Sample meetings for demo mode.
///
/// The schedule only fills the menu. Cut-ins come from scenarios the user picks,
/// laid out so they are due the moment they are added.
public enum DemoCalendar {
  public static let accounts = ["work@example.com", "personal@example.com"]

  public enum Scenario: String, CaseIterable, Sendable {
    case single
    case simultaneous
    case closeTogether

    public var title: String {
      switch self {
      case .single: "Single Meeting"
      case .simultaneous: "Meetings at the Same Time"
      case .closeTogether: "Meetings Close Together"
      }
    }

    public func meetings(now: Date, leadTime: TimeInterval) -> [Meeting] {
      let start = now.addingTimeInterval(leadTime)
      let entries: [Entry] =
        switch self {
        case .single:
          [Entry("weekly-sync", "Weekly sync", start, 30, accounts[0])]
        case .simultaneous:
          [
            Entry("product-review", "Product review", start, 60, accounts[0]),
            Entry("interview", "採用面接（エンジニア）", start, 30, accounts[1]),
          ]
        case .closeTogether:
          [
            Entry("check-in", "Quick check-in", start, 4, accounts[0]),
            Entry("design-review", "デザインレビュー（モバイルアプリ リニューアル）", start.addingTimeInterval(5 * minute), 30, accounts[1]),
          ]
        }
      // A fresh UID per run, so a scenario tried again is never already acknowledged.
      let run = Int(now.timeIntervalSince1970)
      return Meeting.merge([entries.map { $0.meeting(uidPrefix: "\(scenarioPrefix)\(rawValue)-\(run)-") }])
    }
  }

  public static func isScenario(_ meeting: Meeting) -> Bool {
    meeting.uid.hasPrefix(scenarioPrefix)
  }

  public static func meetings(now: Date) -> [Meeting] {
    Meeting.merge([
      [
        Entry("all-hands", "All-hands (in progress)", now.addingTimeInterval(-20 * minute), 45, accounts[0]),
        Entry("standup", "Daily standup", now.addingTimeInterval(30 * minute), 15, accounts[0]),
        Entry("lunch", "Lunch with the team", now.addingTimeInterval(60 * minute), 60, accounts[0], joins: false),
        Entry("planning", "Sprint planning", now.addingTimeInterval(150 * minute), 60, accounts[0]),
        Entry("customer", "Customer call", now.addingTimeInterval(24 * 60 * minute), 30, accounts[1]),
      ].map { $0.meeting(uidPrefix: "demo-") }
    ])
  }

  private static let minute: TimeInterval = 60
  private static let scenarioPrefix = "demo-scenario-"

  private struct Entry {
    var slug: String
    var title: String
    var start: Date
    var minutes: Double
    var account: String
    var joins = true

    init(_ slug: String, _ title: String, _ start: Date, _ minutes: Double, _ account: String, joins: Bool = true) {
      self.slug = slug
      self.title = title
      self.start = start
      self.minutes = minutes
      self.account = account
      self.joins = joins
    }

    func meeting(uidPrefix: String) -> Meeting {
      Meeting(
        uid: uidPrefix + slug,
        title: title,
        start: start,
        end: start.addingTimeInterval(minutes * DemoCalendar.minute),
        joinURL: joins ? URL(string: "https://example.com/demo/join/\(slug)") : nil,
        htmlLink: URL(string: "https://example.com/demo/event/\(slug)"),
        account: account,
        calendarName: "Demo"
      )
    }
  }
}
