import Foundation

/// The days a refresh reads: today and tomorrow, and past them, only when nothing is
/// left before, a further stretch to find the next meeting in.
public struct ReadWindow: Equatable, Sendable {
  private static let lookaheadDays = 14

  /// The start of today.
  public let from: Date
  /// The start of the day after tomorrow.
  public let to: Date
  /// Where the search for the next meeting past `to` stops.
  public let lookaheadEnd: Date
  /// The start of the last day the search for the next meeting covers.
  public let lastLookaheadDay: Date

  public init(now: Date, calendar: Calendar = .current) {
    from = calendar.startOfDay(for: now)
    to = calendar.date(byAdding: .day, value: 2, to: from)!
    lookaheadEnd = calendar.date(byAdding: .day, value: Self.lookaheadDays, to: to)!
    lastLookaheadDay = calendar.date(byAdding: .day, value: -1, to: lookaheadEnd)!
  }

  /// Whether nothing read for the window is left to happen, so the menu would show no meeting.
  public func needsLookahead(after meetings: [Meeting], now: Date) -> Bool {
    !meetings.contains { $0.end > now }
  }

  /// The first meeting that starts past the window. One that only overlaps its end was
  /// read with the window already.
  public func firstAfter(_ meetings: [Meeting]) -> Meeting? {
    meetings.filter { $0.start >= to }.min { $0.start < $1.start }
  }
}
