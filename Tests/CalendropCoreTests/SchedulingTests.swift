import Foundation
import Testing

@testable import CalendropCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func meeting(
  _ uid: String, startsIn minutes: Double, lasting duration: Double = 30, account: String = "a@example.com"
) -> Meeting {
  Meeting(
    uid: uid,
    title: uid,
    start: t0.addingTimeInterval(minutes * 60),
    end: t0.addingTimeInterval((minutes + duration) * 60),
    joinURL: nil,
    htmlLink: nil,
    account: account,
    calendarName: "cal"
  )
}

@Suite struct CutinPolicyTests {
  let policy = CutinPolicy(leadTime: 2 * 60, grace: 5 * 60)

  @Test func doesNotTriggerBeforeLeadTime() {
    #expect(policy.meetingsToCutIn([meeting("a", startsIn: 2.1)], now: t0, acknowledged: []).isEmpty)
  }

  @Test func triggersWithinLeadTime() {
    let due = policy.meetingsToCutIn([meeting("a", startsIn: 2)], now: t0, acknowledged: [])
    #expect(due.map(\.uid) == ["a"])
  }

  @Test func keepsTriggeringShortlyAfterStartForAWokenMac() {
    let due = policy.meetingsToCutIn([meeting("a", startsIn: -4.9)], now: t0, acknowledged: [])
    #expect(due.map(\.uid) == ["a"])
  }

  @Test func stopsAfterGracePeriod() {
    #expect(policy.meetingsToCutIn([meeting("a", startsIn: -5)], now: t0, acknowledged: []).isEmpty)
  }

  @Test func stopsWhenMeetingEndsBeforeGrace() {
    let short = meeting("a", startsIn: -1, lasting: 1)
    #expect(policy.meetingsToCutIn([short], now: t0, acknowledged: []).isEmpty)
  }

  @Test func skipsAcknowledged() {
    let m = meeting("a", startsIn: 1)
    #expect(policy.meetingsToCutIn([m], now: t0, acknowledged: [m.acknowledgementKey]).isEmpty)
  }

  @Test func acknowledgementIsPerOccurrence() {
    let earlier = meeting("a", startsIn: -60 * 24)
    let today = meeting("a", startsIn: 1)
    #expect(earlier.acknowledgementKey != today.acknowledgementKey)
    let due = policy.meetingsToCutIn([today], now: t0, acknowledged: [earlier.acknowledgementKey])
    #expect(due.count == 1)
  }

  @Test func returnsEveryDueMeetingSortedByStart() {
    let due = policy.meetingsToCutIn(
      [meeting("later", startsIn: 1.5), meeting("sooner", startsIn: 0.5), meeting("far", startsIn: 30)],
      now: t0, acknowledged: [])
    #expect(due.map(\.uid) == ["sooner", "later"])
  }

  @Test func zeroLeadTimeTriggersAtStart() {
    let p = CutinPolicy(leadTime: 0, grace: 5 * 60)
    #expect(p.meetingsToCutIn([meeting("a", startsIn: 0.1)], now: t0, acknowledged: []).isEmpty)
    #expect(p.meetingsToCutIn([meeting("a", startsIn: 0)], now: t0, acknowledged: []).count == 1)
  }

  @Test func nextMeetingSkipsThoseStartedLongerAgoThanGrace() {
    let meetings = [meeting("old", startsIn: -10), meeting("now", startsIn: -1), meeting("soon", startsIn: 5)]
    #expect(policy.nextMeeting(in: meetings, now: t0)?.uid == "now")
    #expect(policy.nextMeeting(in: [meetings[0], meetings[2]], now: t0)?.uid == "soon")
    #expect(policy.nextMeeting(in: [meetings[0]], now: t0) == nil)
  }
}

@Suite struct MeetingMergeTests {
  @Test func mergesDuplicatesAcrossAccountsAndSorts() {
    let shared1 = meeting("shared", startsIn: 10, account: "a@example.com")
    let shared2 = meeting("shared", startsIn: 10, account: "b@example.com")
    let other = meeting("other", startsIn: 5, account: "b@example.com")
    let merged = Meeting.merge([[shared1], [shared2, other]])
    #expect(merged.map(\.uid) == ["other", "shared"])
    #expect(merged[1].account == "a@example.com")
  }

  @Test func keepsTheCopyThatHasAJoinURL() {
    let plain = meeting("shared", startsIn: 10, account: "a@example.com")
    var withURL = meeting("shared", startsIn: 10, account: "b@example.com")
    withURL.joinURL = URL(string: "https://meet.google.com/x")
    #expect(Meeting.merge([[plain], [withURL]]).first?.account == "b@example.com")
  }
}

@Suite struct CountdownTests {
  @Test(
    arguments: [
      (0, "now"),
      (-30, "now"),
      (20, "in <1m"),
      (60, "in 1m"),
      (3599, "in 59m"),
      (3600, "in 1h"),
      (7500, "in 2h 5m"),
    ] as [(Double, String)])
  func formatsInterval(seconds: Double, expected: String) {
    #expect(Countdown.short(seconds) == expected)
  }

  @Test(
    arguments: [
      (95, "1:35"),
      (5, "0:05"),
      (-3, "0:00"),
      (3725, "1:02:05"),
    ] as [(Double, String)])
  func formatsClock(seconds: Double, expected: String) {
    #expect(Countdown.clock(seconds) == expected)
  }

  @Test func truncatesByCharacterNotByte() {
    #expect(Countdown.truncate("週次定例ミーティング", to: 4) == "週次定例…")
    #expect(Countdown.truncate("short", to: 10) == "short")
  }
}
