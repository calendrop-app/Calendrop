import CalendropCore
import Foundation
import Testing

@Suite struct SyncStatusTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  @Test(
    arguments: [
      (0, "updated just now"),
      (59, "updated just now"),
      (-30, "updated just now"),
      (60, "updated 1 min ago"),
      (3599, "updated 59 min ago"),
      (3600, "updated 1 h ago"),
      (3 * 3600 + 1800, "updated 3 h ago"),
    ] as [(Double, String)])
  func saysHowLongAgoTheCalendarsWereRead(seconds: Double, expected: String) {
    #expect(SyncStatus.updated(seconds) == expected)
  }

  @Test func countsTheCalendarsReadAndWhen() {
    #expect(
      SyncStatus.summary(calendars: 3, readAt: now.addingTimeInterval(-120), now: now)
        == "3 calendars · updated 2 min ago")
  }

  @Test func countsASingleCalendarInTheSingular() {
    #expect(SyncStatus.summary(calendars: 1, readAt: now, now: now) == "1 calendar · updated just now")
  }

  @Test func saysSoWhenNothingWasReadYet() {
    #expect(SyncStatus.summary(calendars: 0, readAt: nil, now: now) == "Not read yet")
  }
}
