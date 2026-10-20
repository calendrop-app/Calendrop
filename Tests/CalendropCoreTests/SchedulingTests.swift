import Foundation
import Testing

@testable import CalendropCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func meeting(
  _ uid: String, startsIn minutes: Double, lasting duration: Double = 30, account: String = "a@example.com",
  joins: Bool = true
) -> Meeting {
  Meeting(
    uid: uid,
    title: uid,
    start: t0.addingTimeInterval(minutes * 60),
    end: t0.addingTimeInterval((minutes + duration) * 60),
    joinURL: joins ? URL(string: "https://meet.google.com/aaa-bbbb-ccc") : nil,
    htmlLink: nil,
    account: account,
    calendarName: "cal"
  )
}

@Suite struct CutinPolicyTests {
  let policy = CutinPolicy(leadTime: 2 * 60, grace: 5 * 60)

  @Test func skipsMeetingsWithoutAJoinLinkUnlessAsked() {
    let inPerson = meeting("in-person", startsIn: 1, joins: false)
    #expect(policy.meetingsToCutIn([inPerson], now: t0, acknowledged: []).isEmpty)
    #expect(
      policy.cutInGroup([inPerson, meeting("online", startsIn: 1)], now: t0, acknowledged: []).map(\.uid) == ["online"])

    var asked = policy
    asked.includesMeetingsWithoutJoinLink = true
    #expect(asked.meetingsToCutIn([inPerson], now: t0, acknowledged: []).map(\.uid) == ["in-person"])
  }

  @Test func cutsInForTentativeAndUnansweredMeetingsUnlessTurnedOff() {
    var tentative = meeting("tentative", startsIn: 1)
    tentative.response = .tentative
    var unanswered = meeting("unanswered", startsIn: 1)
    unanswered.response = .unanswered
    let accepted = meeting("accepted", startsIn: 1)
    let all = [tentative, unanswered, accepted]
    #expect(policy.meetingsToCutIn(all, now: t0, acknowledged: []).count == 3)

    var acceptedOnly = policy
    acceptedOnly.includesMeetingsNotAccepted = false
    #expect(acceptedOnly.meetingsToCutIn(all, now: t0, acknowledged: []).map(\.uid) == ["accepted"])
    #expect(acceptedOnly.cutInGroup(all, now: t0, acknowledged: []).map(\.uid) == ["accepted"])
  }

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

@Suite struct CutinGroupTests {
  let policy = CutinPolicy(leadTime: 2 * 60, grace: 5 * 60, nearby: 15 * 60)

  private func group(_ meetings: [Meeting], acknowledged: Set<String> = []) -> [String] {
    policy.cutInGroup(meetings, now: t0, acknowledged: acknowledged).map(\.uid)
  }

  @Test func isEmptyUntilSomeMeetingIsDue() {
    #expect(group([meeting("a", startsIn: 3), meeting("b", startsIn: 3)]).isEmpty)
  }

  @Test func gathersMeetingsStartingTogether() {
    #expect(group([meeting("a", startsIn: 1, account: "x"), meeting("b", startsIn: 1, account: "y")]) == ["a", "b"])
  }

  @Test func gathersMeetingsStartingCloseToTheDueOne() {
    let meetings = [
      meeting("due", startsIn: 1, lasting: 5), meeting("soon", startsIn: 16), meeting("far", startsIn: 17),
    ]
    #expect(group(meetings) == ["due", "soon"])
  }

  @Test func neverHoldsBackADueMeetingThatIsFarFromTheFirst() {
    let longLead = CutinPolicy(leadTime: 30 * 60, grace: 5 * 60, nearby: 15 * 60)
    let meetings = [meeting("first", startsIn: 10, lasting: 5), meeting("later", startsIn: 30, lasting: 5)]
    let shown = longLead.cutInGroup(meetings, now: t0, acknowledged: []).map(\.uid)
    #expect(shown == ["first", "later"])
  }

  @Test func gathersMeetingsOverlappingTheDueOne() {
    let meetings = [meeting("due", startsIn: 1, lasting: 60), meeting("inside", startsIn: 40)]
    #expect(group(meetings) == ["due", "inside"])
  }

  @Test func leavesOutStaleAndAcknowledgedMeetings() {
    let ongoing = meeting("ongoing", startsIn: -20, lasting: 60)
    let skipped = meeting("skipped", startsIn: 2)
    let meetings = [ongoing, meeting("due", startsIn: 1), skipped]
    #expect(group(meetings, acknowledged: [skipped.acknowledgementKey]) == ["due"])
  }

  @Test func joiningSettlesTheMeetingsThatOverlapIt() {
    let a = meeting("a", startsIn: 1, lasting: 30)
    let b = meeting("b", startsIn: 1, lasting: 60)
    let later = meeting("later", startsIn: 31, lasting: 30)
    let settled = policy.settledByJoining(a, among: [a, b, later]).map(\.uid)
    #expect(settled == ["a", "b"])
  }

  @Test func joiningLeavesALaterMeetingToCutInAgain() {
    let a = meeting("a", startsIn: 1, lasting: 4)
    let b = meeting("b", startsIn: 6, lasting: 30)
    let settled = policy.settledByJoining(a, among: [a, b])
    #expect(settled.map(\.uid) == ["a"])
    let afterJoin = t0.addingTimeInterval(4 * 60)
    #expect(
      policy.cutInGroup([a, b], now: afterJoin, acknowledged: Set(settled.map(\.acknowledgementKey))).map(\.uid) == [
        "b"
      ])
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
    let plain = meeting("shared", startsIn: 10, account: "a@example.com", joins: false)
    var withURL = meeting("shared", startsIn: 10, account: "b@example.com")
    withURL.joinURL = URL(string: "https://meet.google.com/x")
    #expect(Meeting.merge([[plain], [withURL]]).first?.account == "b@example.com")
  }

  @Test func keepsTheFirmestResponseAcrossAccounts() {
    var unanswered = meeting("shared", startsIn: 10, account: "a@example.com")
    unanswered.response = .unanswered
    var tentative = meeting("shared", startsIn: 10, account: "b@example.com")
    tentative.response = .tentative
    let accepted = meeting("shared", startsIn: 10, account: "c@example.com")
    #expect(Meeting.merge([[unanswered], [tentative]]).first?.response == .tentative)
    #expect(Meeting.merge([[unanswered], [tentative], [accepted]]).first?.response == .accepted)
    #expect(Meeting.merge([[accepted], [unanswered]]).first?.response == .accepted)
  }
}

@Suite struct CountdownTests {
  @Test(
    arguments: [
      (0, "now", "進行中"),
      (-30, "now", "進行中"),
      (20, "in <1m", "1分以内"),
      (59.9, "in <1m", "1分以内"),
      (60, "in 1m", "1分後"),
      (60.1, "in 2m", "2分後"),
      (119.9, "in 2m", "2分後"),
      (120, "in 2m", "2分後"),
      (120.1, "in 3m", "3分後"),
      (3599, "in 1h", "1時間後"),
      (3600, "in 1h", "1時間後"),
      (3600.1, "in 1h 1m", "1時間1分後"),
      (7500, "in 2h 5m", "2時間5分後"),
    ] as [(Double, String, String)])
  func formatsInterval(seconds: Double, english: String, japanese: String) {
    #expect(Countdown.short(seconds, locale: Locale(identifier: "en")) == english)
    #expect(Countdown.short(seconds, locale: Locale(identifier: "ja")) == japanese)
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

  @Test(arguments: [
    "모바일 앱 리뉴얼 디자인 리뷰",
    "\u{1100}\u{1161}\u{11A8}\u{1100}\u{1161}\u{11A8}\u{1100}\u{1161}\u{11A8}\u{1100}\u{1161}\u{11A8}",
    "移动应用改版设计评审",
    "行動應用程式改版設計審查",
    "مراجعة تصميم تطبيق الجوال",
    "ประชุมทบทวนการออกแบบแอป",
    "नमस्ते दुनिया की बैठक",
    "👨‍👩‍👧‍👦👨‍👩‍👧‍👦🇯🇵🇰🇷🏳️‍🌈👍🏽",
  ])
  func neverCutsACharacterApartInAnyScript(title: String) {
    let truncated = Countdown.truncate(title, to: 3)
    let kept = Array(truncated.dropLast())
    #expect(truncated.hasSuffix("…"))
    #expect(kept.count == 3)
    #expect(Array(title).starts(with: kept))
  }
}
