import Foundation

/// A sample schedule for demo mode, timed relative to `now` so every behaviour
/// shows up within minutes of launch.
public enum DemoCalendar {
  public static let accounts = ["work@example.com", "personal@example.com"]

  /// How long after launch the first cut-in appears.
  public static let firstCutInDelay: TimeInterval = 20
  /// How long after the first cut-in a meeting from the other account joins it.
  public static let overlapDelay: TimeInterval = 30

  public static func meetings(now: Date, leadTime: TimeInterval) -> [Meeting] {
    let firstStart = now.addingTimeInterval(leadTime + firstCutInDelay)
    let minute: TimeInterval = 60
    let entries: [(slug: String, title: String, start: Date, length: TimeInterval, account: String, joins: Bool)] = [
      ("all-hands", "All-hands (in progress)", now.addingTimeInterval(-20 * minute), 45 * minute, accounts[0], true),
      ("standup", "Daily standup", firstStart, 15 * minute, accounts[0], true),
      (
        "design-review", "デザインレビュー（モバイルアプリ リニューアル）", firstStart.addingTimeInterval(overlapDelay),
        30 * minute, accounts[1], true
      ),
      ("lunch", "Lunch with the team", now.addingTimeInterval(45 * minute), 60 * minute, accounts[0], false),
      ("planning", "Sprint planning", now.addingTimeInterval(120 * minute), 60 * minute, accounts[0], true),
      ("customer", "Customer call", now.addingTimeInterval(24 * 60 * minute), 30 * minute, accounts[1], true),
    ]
    return Meeting.merge([
      entries.map { e in
        Meeting(
          uid: "demo-\(e.slug)",
          title: e.title,
          start: e.start,
          end: e.start.addingTimeInterval(e.length),
          joinURL: e.joins ? URL(string: "https://example.com/demo/join/\(e.slug)") : nil,
          htmlLink: URL(string: "https://example.com/demo/event/\(e.slug)"),
          account: e.account,
          calendarName: "Demo"
        )
      }
    ])
  }
}
