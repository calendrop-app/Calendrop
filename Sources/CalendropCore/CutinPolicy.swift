import Foundation

/// Decides when a meeting interrupts the user and which meeting the menu bar announces.
public struct CutinPolicy: Sendable {
  /// How long before the start the cut-in appears.
  public var leadTime: TimeInterval
  /// How long after the start a still-unacknowledged meeting keeps cutting in, so a
  /// Mac that wakes from sleep just after the start still interrupts.
  public var grace: TimeInterval
  /// Meetings starting within this distance of a due meeting share its cut-in, so
  /// the user sees the conflict at once instead of one interruption after another.
  public var nearby: TimeInterval
  /// Whether a meeting with nothing to join, such as an in-person one, cuts in too.
  public var includesMeetingsWithoutJoinLink: Bool
  /// Whether a meeting the user answered "maybe" to, or has not answered, cuts in too.
  public var includesMeetingsNotAccepted: Bool

  public init(
    leadTime: TimeInterval, grace: TimeInterval = 5 * 60, nearby: TimeInterval = 15 * 60,
    includesMeetingsWithoutJoinLink: Bool = false, includesMeetingsNotAccepted: Bool = true
  ) {
    self.leadTime = leadTime
    self.grace = grace
    self.nearby = nearby
    self.includesMeetingsWithoutJoinLink = includesMeetingsWithoutJoinLink
    self.includesMeetingsNotAccepted = includesMeetingsNotAccepted
  }

  private func mayCutIn(_ meeting: Meeting) -> Bool {
    (includesMeetingsWithoutJoinLink || meeting.joinURL != nil)
      && (includesMeetingsNotAccepted || meeting.response == .accepted)
  }

  /// Everything one cut-in shows: every due meeting, plus every meeting that starts
  /// near the earliest one or overlaps it, leaving out stale and acknowledged ones.
  public func cutInGroup(_ meetings: [Meeting], now: Date, acknowledged: Set<String>) -> [Meeting] {
    let due = meetingsToCutIn(meetings, now: now, acknowledged: acknowledged)
    guard let anchor = due.first else { return [] }
    let dueKeys = Set(due.map(\.acknowledgementKey))
    return
      meetings
      .filter { m in
        guard mayCutIn(m), !acknowledged.contains(m.acknowledgementKey), m.end > now,
          m.start.addingTimeInterval(grace) > now
        else { return false }
        return dueKeys.contains(m.acknowledgementKey) || abs(m.start.timeIntervalSince(anchor.start)) <= nearby
          || m.overlaps(anchor)
      }
      .sorted { $0.start < $1.start }
  }

  /// The meetings joining `joined` settles: itself and those it overlaps, which the
  /// user has chosen not to attend. Later meetings stay to cut in at their own time.
  public func settledByJoining(_ joined: Meeting, among shown: [Meeting]) -> [Meeting] {
    shown.filter { $0.acknowledgementKey == joined.acknowledgementKey || $0.overlaps(joined) }
  }

  public func meetingsToCutIn(_ meetings: [Meeting], now: Date, acknowledged: Set<String>) -> [Meeting] {
    meetings
      .filter { m in
        let opens = m.start.addingTimeInterval(-leadTime)
        let closes = min(m.end, m.start.addingTimeInterval(grace))
        return mayCutIn(m) && opens <= now && now < closes && !acknowledged.contains(m.acknowledgementKey)
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
  public static func short(_ interval: TimeInterval, locale: Locale = .current) -> String {
    let minutes = Int((interval / 60).rounded(.up))
    let (h, m) = minutes.quotientAndRemainder(dividingBy: 60)
    let text =
      if interval <= 0 {
        LocalizedStringResource("now", locale: locale, bundle: .core)
      } else if interval < 60 {
        LocalizedStringResource("in <1m", locale: locale, bundle: .core)
      } else if h == 0 {
        LocalizedStringResource("in \(m)m", locale: locale, bundle: .core)
      } else if m == 0 {
        LocalizedStringResource("in \(h)h", locale: locale, bundle: .core)
      } else {
        LocalizedStringResource("in \(h)h \(m)m", locale: locale, bundle: .core)
      }
    return String(localized: text)
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
