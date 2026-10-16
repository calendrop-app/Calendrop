import CalendropCore
import Foundation
import Testing

@Suite struct ReadWindowTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
  }()

  private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
  }

  private func meeting(_ id: String, start: Date, minutes: Double = 30) -> Meeting {
    Meeting(
      uid: id, title: id, start: start, end: start.addingTimeInterval(minutes * 60), joinURL: nil,
      htmlLink: nil, account: "a@example.com", calendarName: "Work")
  }

  @Test func coversTodayAndTomorrow() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(window.from == date(16, 0))
    #expect(window.to == date(18, 0))
  }

  @Test func looksTwoWeeksPastTomorrow() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(window.lookaheadEnd == date(32, 0))
    #expect(window.lastLookaheadDay == date(31, 0))
  }

  @Test func looksAheadWhenNothingWasFound() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(window.needsLookahead(after: [], now: date(16, 15)))
  }

  @Test func looksAheadWhenEveryMeetingHasEnded() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(window.needsLookahead(after: [meeting("m", start: date(16, 10))], now: date(16, 15)))
  }

  @Test func doesNotLookAheadWhileAMeetingIsUnderWay() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(!window.needsLookahead(after: [meeting("m", start: date(16, 14, 50))], now: date(16, 15)))
  }

  @Test func doesNotLookAheadWhileAMeetingIsStillToCome() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(!window.needsLookahead(after: [meeting("m", start: date(17, 9))], now: date(16, 15)))
  }

  @Test func picksTheEarliestMeetingThatStartsPastTheWindow() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    let found = [
      meeting("later", start: date(22, 10)),
      // Overlaps the window's end, so it was already read with the window.
      meeting("overnight", start: date(17, 23), minutes: 120),
      meeting("first", start: date(20, 9)),
    ]
    #expect(window.firstAfter(found)?.uid == "first")
  }

  @Test func findsNothingPastTheWindowInAnEmptyList() {
    let window = ReadWindow(now: date(16, 15), calendar: calendar)
    #expect(window.firstAfter([]) == nil)
  }
}
