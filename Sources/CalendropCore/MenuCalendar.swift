import Foundation

/// What the menu shows above its meetings.
public enum MenuCalendarMode: String, Codable, CaseIterable, Sendable {
  case hidden, month, week

  public var span: MenuCalendar.Span? {
    switch self {
    case .hidden: nil
    case .month: .month
    case .week: .week
    }
  }
}

/// The meetings read for the days a menu calendar shows.
public struct PeriodRead: Equatable, Sendable {
  public let interval: DateInterval
  public let meetings: [Meeting]

  public init(interval: DateInterval, meetings: [Meeting]) {
    self.interval = interval
    self.meetings = meetings
  }
}

/// The days a menu calendar shows around the selected day, and where paging takes the
/// selection. The shown period is always the one holding the selection, so the grid
/// and the meetings listed under it never disagree.
public struct MenuCalendar: Equatable, Sendable {
  public enum Span: Sendable { case month, week }

  public let span: Span
  public let calendar: Calendar

  public init(span: Span, calendar: Calendar = .current) {
    self.span = span
    self.calendar = calendar
  }

  /// A week, or the six weeks from the one holding the month's first day: a month that
  /// fits in fewer still gets six, so paging never changes the menu's height.
  public func days(showing selection: Date) -> [Date] {
    let first =
      switch span {
      case .week: weekStart(of: selection)
      case .month: weekStart(of: calendar.dateInterval(of: .month, for: selection)!.start)
      }
    return (0..<(span == .week ? 7 : 42)).map { calendar.date(byAdding: .day, value: $0, to: first)! }
  }

  public func interval(showing selection: Date) -> DateInterval {
    let days = days(showing: selection)
    return DateInterval(start: days.first!, end: calendar.date(byAdding: .day, value: 1, to: days.last!)!)
  }

  /// Whether `day` belongs to a month other than the shown one; a week has no such days.
  public func isOutsidePeriod(_ day: Date, showing selection: Date) -> Bool {
    span == .month && !calendar.isDate(day, equalTo: selection, toGranularity: .month)
  }

  /// One page earlier or later. A month keeps the day of the month, or takes the last
  /// day of a shorter one.
  public func moved(_ selection: Date, by pages: Int) -> Date {
    let day = calendar.startOfDay(for: selection)
    return switch span {
    case .week: calendar.date(byAdding: .day, value: 7 * pages, to: day)!
    case .month: calendar.date(byAdding: .month, value: pages, to: day)!
    }
  }

  /// A day's meetings: for the days the regular refresh reads, as it last read them,
  /// since cut-ins act on those; otherwise from `period`. Nil when nothing read covers the day.
  public func meetings(on day: Date, refreshed: [Meeting], window: ReadWindow, period: PeriodRead?) -> [Meeting]? {
    let start = calendar.startOfDay(for: day)
    let source: [Meeting]
    if start >= window.from && start < window.to {
      source = refreshed
    } else if let period, period.interval.start <= start && start < period.interval.end {
      source = period.meetings
    } else {
      return nil
    }
    return source.filter { calendar.isDate($0.start, inSameDayAs: start) }
  }

  private func weekStart(of date: Date) -> Date {
    calendar.dateInterval(of: .weekOfYear, for: date)!.start
  }
}
