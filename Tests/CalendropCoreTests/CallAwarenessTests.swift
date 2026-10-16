import Foundation
import Testing

@testable import CalendropCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func meeting(_ uid: String, endsIn minutes: Double) -> Meeting {
  Meeting(
    uid: uid, title: uid, start: t0.addingTimeInterval(-30 * 60), end: t0.addingTimeInterval(minutes * 60),
    joinURL: URL(string: "https://meet.google.com/aaa-bbbb-ccc"), htmlLink: nil, account: "a@example.com",
    calendarName: "cal")
}

@Suite struct CallAwarenessTests {
  private func awareness(_ duringCall: CutinPresentation, coverAfterCall: Bool) -> CallAwareness {
    CallAwareness(duringCall: duringCall, coverAfterCall: coverAfterCall)
  }

  @Test(arguments: CutinPresentation.allCases)
  func aCutInArrivingOutsideACallCoversEveryScreen(duringCall: CutinPresentation) {
    for cover in [true, false] {
      let a = awareness(duringCall, coverAfterCall: cover)
      #expect(a.presentation(inCall: false, showing: nil, arriving: true) == .fullScreen)
    }
  }

  @Test(arguments: CutinPresentation.allCases)
  func aCutInArrivingDuringACallTakesTheChosenForm(duringCall: CutinPresentation) {
    let a = awareness(duringCall, coverAfterCall: false)
    #expect(a.presentation(inCall: true, showing: nil, arriving: true) == duringCall)
  }

  @Test func aCutInCoveringTheScreenNeverShrinksWhenACallStarts() {
    let a = awareness(.compact, coverAfterCall: false)
    #expect(a.presentation(inCall: true, showing: .fullScreen, arriving: false) == .fullScreen)
    #expect(a.presentation(inCall: true, showing: .fullScreen, arriving: true) == .fullScreen)
  }

  @Test(arguments: [CutinPresentation.compact, .hidden])
  func aHeldBackCutInCoversTheScreenWhenTheCallEndsIfAsked(held: CutinPresentation) {
    #expect(
      awareness(held, coverAfterCall: true).presentation(inCall: false, showing: held, arriving: false) == .fullScreen)
  }

  @Test(arguments: [CutinPresentation.compact, .hidden])
  func aHeldBackCutInStaysAsItIsWhenTheCallEndsUnlessAsked(held: CutinPresentation) {
    #expect(awareness(held, coverAfterCall: false).presentation(inCall: false, showing: held, arriving: false) == held)
  }

  @Test func aMeetingComingDueAfterTheCallCoversTheScreenEvenOverAHeldBackOne() {
    let a = awareness(.hidden, coverAfterCall: false)
    #expect(a.presentation(inCall: false, showing: .hidden, arriving: true) == .fullScreen)
  }

  @Test func aChangedSettingAppliesToTheCutInOfTheCallUnderWay() {
    let a = awareness(.hidden, coverAfterCall: false)
    #expect(a.presentation(inCall: true, showing: .compact, arriving: false) == .hidden)
  }

  @Test func aCutInHeldBackLetsGoOfMeetingsThatHaveEnded() {
    let a = awareness(.compact, coverAfterCall: true)
    let ended = meeting("ended", endsIn: 0)
    let ongoing = meeting("ongoing", endsIn: 1)
    #expect(a.kept([ended, ongoing], showing: .compact, now: t0, latest: [ended, ongoing]).map(\.uid) == ["ongoing"])
    #expect(a.kept([ended, ongoing], showing: .hidden, now: t0, latest: [ended, ongoing]).map(\.uid) == ["ongoing"])
  }

  @Test func aCutInHeldBackFollowsTheCalendarWhenAMeetingEndsEarlier() {
    let a = awareness(.hidden, coverAfterCall: true)
    let held = meeting("a", endsIn: 30)
    let shortened = meeting("a", endsIn: -1)
    #expect(a.kept([held], showing: .hidden, now: t0, latest: [shortened]).isEmpty)
    let moved = meeting("a", endsIn: 45)
    #expect(a.kept([held], showing: .compact, now: t0, latest: [moved]).map(\.end) == [moved.end])
  }

  @Test func aCutInHeldBackLetsGoOfMeetingsGoneFromTheCalendar() {
    let a = awareness(.compact, coverAfterCall: true)
    #expect(a.kept([meeting("cancelled", endsIn: 30)], showing: .compact, now: t0, latest: []).isEmpty)
  }

  @Test func aCutInCoveringTheScreenKeepsEveryMeetingUntilTheUserActs() {
    let a = awareness(.compact, coverAfterCall: true)
    let ended = meeting("ended", endsIn: -10)
    #expect(a.kept([ended], showing: .fullScreen, now: t0, latest: []).map(\.uid) == ["ended"])
  }
}

@Suite struct ArrivalTrackerTests {
  @Test func aMeetingComingDueForTheFirstTimeArrives() {
    var tracker = ArrivalTracker()
    let arrived = tracker.arrive([meeting("a", endsIn: 30)])
    #expect(arrived)
  }

  @Test func aMeetingStillDueOnTheNextTickDoesNotArriveAgain() {
    var tracker = ArrivalTracker()
    _ = tracker.arrive([meeting("a", endsIn: 30)])
    let arrived = tracker.arrive([meeting("a", endsIn: 30)])
    #expect(!arrived)
  }

  @Test func aMeetingHeldEarlyArrivesWhenItComesDueItself() {
    var tracker = ArrivalTracker()
    _ = tracker.arrive([meeting("first", endsIn: 30)])
    let arrived = tracker.arrive([meeting("first", endsIn: 30), meeting("near", endsIn: 40)])
    #expect(arrived)
  }

  @Test func forgetsEverythingOnceTheCutInCloses() {
    var tracker = ArrivalTracker()
    _ = tracker.arrive([meeting("a", endsIn: 30)])
    tracker.reset()
    let arrived = tracker.arrive([meeting("a", endsIn: 30)])
    #expect(arrived)
  }
}

@Suite struct CallDetectorTests {
  @Test func isInACallWhileADeviceIsInUse() {
    var detector = CallDetector(settle: 5)
    let inCall = detector.update(deviceInUse: true, now: t0)
    #expect(inCall)
  }

  @Test func isNotInACallBeforeAnyDeviceWasUsed() {
    var detector = CallDetector(settle: 5)
    let inCall = detector.update(deviceInUse: false, now: t0)
    #expect(!inCall)
  }

  @Test func staysInTheCallThroughABriefRelease() {
    var detector = CallDetector(settle: 5)
    _ = detector.update(deviceInUse: true, now: t0)
    let inCall = detector.update(deviceInUse: false, now: t0.addingTimeInterval(4.9))
    #expect(inCall)
  }

  @Test func leavesTheCallOnceTheDevicesStayReleased() {
    var detector = CallDetector(settle: 5)
    _ = detector.update(deviceInUse: true, now: t0)
    let inCall = detector.update(deviceInUse: false, now: t0.addingTimeInterval(5))
    #expect(!inCall)
  }
}
