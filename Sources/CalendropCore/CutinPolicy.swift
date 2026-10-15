import Foundation

/// Decides when a meeting interrupts the user and which meeting the menu bar announces.
public struct CutinPolicy: Sendable {
  /// How long before the start the cut-in appears.
  public var leadTime: TimeInterval
  /// How long after the start a still-unacknowledged meeting keeps cutting in, so a
  /// Mac that wakes from sleep just after the start still interrupts.
  public var grace: TimeInterval

  public init(leadTime: TimeInterval, grace: TimeInterval = 5 * 60) {
    self.leadTime = leadTime
    self.grace = grace
  }

  public func meetingsToCutIn(_ meetings: [Meeting], now: Date, acknowledged: Set<String>) -> [Meeting] {
    meetings
      .filter { m in
        let opens = m.start.addingTimeInterval(-leadTime)
        let closes = min(m.end, m.start.addingTimeInterval(grace))
        return opens <= now && now < closes && !acknowledged.contains(m.acknowledgementKey)
      }
      .sorted { $0.start < $1.start }
  }

  /// The meeting to show in the menu bar: one that started within the grace period,
  /// or else the next one to start.
  public func nextMeeting(in meetings: [Meeting], now: Date) -> Meeting? {
    meetings
      .filter { $0.end > now && $0.start.addingTimeInterval(grace) > now }
      .min { $0.start < $1.start }
  }
}

public enum Countdown {
  /// Compact form for the menu bar: "in 12m", "in 2h 5m", "now".
  public static func short(_ interval: TimeInterval) -> String {
    if interval <= 0 { return "now" }
    let minutes = Int(interval / 60)
    if minutes < 1 { return "in <1m" }
    let (h, m) = minutes.quotientAndRemainder(dividingBy: 60)
    switch (h, m) {
    case (0, _): return "in \(m)m"
    case (_, 0): return "in \(h)h"
    default: return "in \(h)h \(m)m"
    }
  }

  /// Ticking form for the cut-in: "1:35", "1:02:05".
  public static func clock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    let (h, rest) = total.quotientAndRemainder(dividingBy: 3600)
    let (m, s) = rest.quotientAndRemainder(dividingBy: 60)
    return h > 0
      ? String(format: "%d:%02d:%02d", h, m, s)
      : String(format: "%d:%02d", m, s)
  }

  /// Shortens by grapheme cluster so Japanese and emoji are never cut mid-character.
  public static func truncate(_ text: String, to length: Int) -> String {
    text.count <= length ? text : String(text.prefix(length)) + "…"
  }
}
