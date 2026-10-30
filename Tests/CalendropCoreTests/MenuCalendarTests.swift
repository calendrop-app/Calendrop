import CalendropCore
import Foundation
import Testing

@Suite struct MenuCalendarTests {
  private func calendar(firstWeekday: Int = 1, zone: String = "Asia/Tokyo") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    calendar.firstWeekday = firstWeekday
    return calendar
  }

  private func day(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, in calendar: Calendar? = nil) -> Date {
    (calendar ?? self.calendar()).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func meeting(_ id: String, start: Date) -> Meeting {
    Meeting(
      uid: id, title: id, start: start, end: start.addingTimeInterval(1800), joinURL: nil,
      htmlLink: nil, account: "a@example.com", calendarName: "Work")
  }

  // MARK: Mode

  @Test func showsAMonthAWeekOrNothing() {
    #expect(MenuCalendarMode.hidden.span == nil)
    #expect(MenuCalendarMode.month.span == .month)
    #expect(MenuCalendarMode.week.span == .week)
  }

  // MARK: Days shown

  @Test func aWeekIsTheSevenDaysFromTheFirstWeekday() {
    let sunday = MenuCalendar(span: .week, calendar: calendar(firstWeekday: 1))
    #expect(sunday.days(showing: day(2026, 10, 30, 14)) == (25...31).map { day(2026, 10, $0) })
    let monday = MenuCalendar(span: .week, calendar: calendar(firstWeekday: 2))
    #expect(monday.days(showing: day(2026, 10, 30, 14)) == (26...32).map { day(2026, 10, $0) })
  }

  @Test func aMonthIsAlwaysSixWeeksFromTheWeekOfItsFirstDay() {
    let month = MenuCalendar(span: .month, calendar: calendar())
    let october = month.days(showing: day(2026, 10, 30))
    #expect(october.count == 42)
    #expect(october.first == day(2026, 9, 27))
    #expect(october.last == day(2026, 11, 7))
    // February 2026 starts on a Sunday and fits four weeks, and still gets six.
    let february = month.days(showing: day(2026, 2, 10))
    #expect(february.count == 42)
    #expect(february.first == day(2026, 2, 1))
  }

  @Test func daysStartAtMidnightAcrossADaylightSavingChange() {
    let newYork = calendar(zone: "America/New_York")
    let week = MenuCalendar(span: .week, calendar: newYork)
    // Daylight saving time ends on Sunday 1 November 2026 in New York.
    let days = week.days(showing: day(2026, 11, 3, 12, in: newYork))
    #expect(days == (1...7).map { day(2026, 11, $0, in: newYork) })
  }

  @Test func readsFromTheFirstShownDayToTheEndOfTheLast() {
    let month = MenuCalendar(span: .month, calendar: calendar())
    #expect(month.interval(showing: day(2026, 10, 30)) == DateInterval(start: day(2026, 9, 27), end: day(2026, 11, 8)))
  }

  @Test func tellsTheDaysOfOtherMonthsApart() {
    let month = MenuCalendar(span: .month, calendar: calendar())
    #expect(month.isOutsidePeriod(day(2026, 11, 1), showing: day(2026, 10, 30)))
    #expect(!month.isOutsidePeriod(day(2026, 10, 1), showing: day(2026, 10, 30)))
    let week = MenuCalendar(span: .week, calendar: calendar())
    #expect(!week.isOutsidePeriod(day(2026, 11, 1), showing: day(2026, 10, 30)))
  }

  // MARK: Paging

  @Test func pagingAWeekMovesTheSelectionSevenDays() {
    let week = MenuCalendar(span: .week, calendar: calendar())
    #expect(week.moved(day(2026, 12, 30), by: 1) == day(2027, 1, 6))
    #expect(week.moved(day(2026, 10, 30), by: -1) == day(2026, 10, 23))
  }

  @Test(arguments: [
    // (from, by, to): the same day of the month, or the last day of a shorter one.
    ((2026, 10, 15), 1, (2026, 11, 15)),
    ((2026, 10, 31), 1, (2026, 11, 30)),
    ((2026, 3, 31), -1, (2026, 2, 28)),
    ((2028, 1, 31), 1, (2028, 2, 29)),
    ((2026, 12, 15), 1, (2027, 1, 15)),
    ((2026, 1, 15), -1, (2025, 12, 15)),
  ])
  func pagingAMonthKeepsTheDayOfTheMonth(from: (Int, Int, Int), by: Int, to: (Int, Int, Int)) {
    let month = MenuCalendar(span: .month, calendar: calendar())
    #expect(month.moved(day(from.0, from.1, from.2), by: by) == day(to.0, to.1, to.2))
  }

  // MARK: Meetings of a day

  @Test func takesTheDaysTheRefreshReadsFromIt() {
    let month = MenuCalendar(span: .month, calendar: calendar())
    let window = ReadWindow(now: day(2026, 10, 30, 14), calendar: calendar())
    let refreshed = [meeting("fresh", start: day(2026, 10, 31, 9))]
    let period = PeriodRead(
      interval: month.interval(showing: day(2026, 10, 30)),
      meetings: [meeting("stale", start: day(2026, 10, 31, 9)), meeting("later", start: day(2026, 11, 2, 9))])
    #expect(
      month.meetings(on: day(2026, 10, 31), refreshed: refreshed, window: window, period: period)?.map(\.uid)
        == ["fresh"])
    #expect(
      month.meetings(on: day(2026, 11, 2), refreshed: refreshed, window: window, period: period)?.map(\.uid)
        == ["later"])
    #expect(month.meetings(on: day(2026, 11, 3), refreshed: refreshed, window: window, period: period) == [])
  }

  @Test func knowsNothingOfADayNoReadCovers() {
    let month = MenuCalendar(span: .month, calendar: calendar())
    let window = ReadWindow(now: day(2026, 10, 30, 14), calendar: calendar())
    let october = PeriodRead(interval: month.interval(showing: day(2026, 10, 30)), meetings: [])
    #expect(month.meetings(on: day(2026, 12, 1), refreshed: [], window: window, period: october) == nil)
    #expect(month.meetings(on: day(2026, 11, 2), refreshed: [], window: window, period: nil) == nil)
  }

  @Test func placesAMeetingOnTheDayItStarts() {
    let week = MenuCalendar(span: .week, calendar: calendar())
    let window = ReadWindow(now: day(2026, 10, 20), calendar: calendar())
    let lateNight = meeting("late", start: day(2026, 10, 27, 23).addingTimeInterval(1800))
    let period = PeriodRead(interval: week.interval(showing: day(2026, 10, 27)), meetings: [lateNight])
    #expect(week.meetings(on: day(2026, 10, 27), refreshed: [], window: window, period: period)?.count == 1)
    #expect(week.meetings(on: day(2026, 10, 28), refreshed: [], window: window, period: period) == [])
  }
}
