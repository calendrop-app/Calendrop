import CalendropCore
import Foundation
import Testing

@Suite struct SyncStatusTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let en = Locale(identifier: "en")
  private let ja = Locale(identifier: "ja")

  @Test(
    arguments: [
      (0, "updated just now", "たった今更新"),
      (59, "updated just now", "たった今更新"),
      (-30, "updated just now", "たった今更新"),
      (60, "updated 1 min ago", "1分前に更新"),
      (3599, "updated 59 min ago", "59分前に更新"),
      (3600, "updated 1 h ago", "1時間前に更新"),
      (3 * 3600 + 1800, "updated 3 h ago", "3時間前に更新"),
    ] as [(Double, String, String)])
  func saysHowLongAgoTheCalendarsWereRead(seconds: Double, english: String, japanese: String) {
    #expect(SyncStatus.updated(seconds, locale: en) == english)
    #expect(SyncStatus.updated(seconds, locale: ja) == japanese)
  }

  @Test func countsTheCalendarsReadAndWhen() {
    let readAt = now.addingTimeInterval(-120)
    #expect(
      SyncStatus.summary(calendars: 3, readAt: readAt, now: now, locale: en) == "3 calendars · updated 2 min ago")
    #expect(SyncStatus.summary(calendars: 3, readAt: readAt, now: now, locale: ja) == "カレンダー3件 · 2分前に更新")
  }

  @Test func countsASingleCalendarInTheSingular() {
    #expect(SyncStatus.summary(calendars: 1, readAt: now, now: now, locale: en) == "1 calendar · updated just now")
  }

  @Test func saysSoWhenNothingWasReadYet() {
    #expect(SyncStatus.summary(calendars: 0, readAt: nil, now: now, locale: en) == "Not read yet")
    #expect(SyncStatus.summary(calendars: 0, readAt: nil, now: now, locale: ja) == "まだ読み込んでいません")
  }
}
