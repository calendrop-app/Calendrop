import CalendropCore
import Foundation
import Testing

@Suite struct MenuBarLabelTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let english = Locale(identifier: "en")

  private func meeting(_ title: String, startsIn minutes: Double) -> Meeting {
    let start = now.addingTimeInterval(minutes * 60)
    return Meeting(
      uid: title, title: title, start: start, end: start.addingTimeInterval(1800), joinURL: nil,
      htmlLink: nil, account: "a@example.com", calendarName: "cal")
  }

  @Test func showsTheTitleAndCountdown() {
    #expect(
      MenuBarLabel.text(meeting: meeting("Standup", startsIn: 5), now: now, showTitle: true, locale: english)
        == "Standup · in 5m")
  }

  @Test func hidesOnlyTheTitle() {
    #expect(
      MenuBarLabel.text(meeting: meeting("Private meeting", startsIn: 5), now: now, showTitle: false, locale: english)
        == "in 5m")
  }

  @Test(arguments: [true, false])
  func showsNothingWithoutAMeeting(showTitle: Bool) {
    #expect(MenuBarLabel.text(meeting: nil, now: now, showTitle: showTitle) == nil)
  }

  @Test func truncatesLongTitles() {
    let long = String(repeating: "a", count: MenuBarLabel.titleLength + 1)
    #expect(
      MenuBarLabel.text(meeting: meeting(long, startsIn: 5), now: now, showTitle: true, locale: english)
        == String(repeating: "a", count: MenuBarLabel.titleLength) + "… · in 5m")
  }
}
