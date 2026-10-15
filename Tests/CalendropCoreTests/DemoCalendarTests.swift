import Foundation
import Testing

@testable import CalendropCore

@Suite struct DemoCalendarTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let policy = CutinPolicy(leadTime: 2 * 60)

  private var schedule: [Meeting] { DemoCalendar.meetings(now: now) }

  private func group(_ scenario: DemoCalendar.Scenario, at time: Date? = nil, acknowledged: Set<String> = [])
    -> [Meeting]
  {
    let meetings = scenario.meetings(now: now, leadTime: policy.leadTime)
    return policy.cutInGroup(meetings, now: time ?? now, acknowledged: acknowledged)
  }

  @Test func scheduleNeverCutsInByItself() {
    #expect(!schedule.contains(where: DemoCalendar.isScenario))
  }

  @Test func scheduleCoversWhatTheMenuShows() {
    #expect(schedule.contains { $0.start < now && $0.end > now })
    #expect(schedule.contains { $0.joinURL == nil })
    #expect(schedule.contains { !Calendar.current.isDate($0.start, inSameDayAs: now) })
    #expect(Set(schedule.map(\.account)) == Set(DemoCalendar.accounts))
  }

  @Test(arguments: DemoCalendar.Scenario.allCases)
  func scenarioIsDueTheMomentItIsAdded(scenario: DemoCalendar.Scenario) {
    let meetings = scenario.meetings(now: now, leadTime: policy.leadTime)
    #expect(meetings.allSatisfy(DemoCalendar.isScenario))
    #expect(!group(scenario).isEmpty)
  }

  @Test func singleShowsOneMeeting() {
    #expect(group(.single).count == 1)
  }

  @Test func simultaneousShowsAConflictAcrossAccounts() {
    let shown = group(.simultaneous)
    #expect(shown.count == 2)
    #expect(shown[0].overlaps(shown[1]))
    #expect(Set(shown.map(\.account)).count == 2)
  }

  @Test func closeTogetherCutsInAgainForTheSecondMeeting() {
    let shown = group(.closeTogether)
    #expect(shown.count == 2)
    #expect(!shown[0].overlaps(shown[1]))
    let settled = Set(policy.settledByJoining(shown[0], among: shown).map(\.acknowledgementKey))
    #expect(group(.closeTogether, acknowledged: settled).isEmpty)
    let again = group(.closeTogether, at: shown[1].start.addingTimeInterval(-policy.leadTime), acknowledged: settled)
    #expect(again.map(\.id) == [shown[1].id])
  }

  @Test func scenarioTriedAgainIsNotAlreadyAcknowledged() {
    let first = DemoCalendar.Scenario.single.meetings(now: now, leadTime: 0)
    let second = DemoCalendar.Scenario.single.meetings(now: now.addingTimeInterval(1), leadTime: 0)
    #expect(Set(first.map(\.acknowledgementKey)).isDisjoint(with: second.map(\.acknowledgementKey)))
  }

  @Test func neverPointsAtARealMeeting() {
    let all = schedule + DemoCalendar.Scenario.allCases.flatMap { $0.meetings(now: now, leadTime: 0) }
    #expect(all.compactMap(\.openURL).allSatisfy { $0.host == "example.com" })
  }

  @Test func isSortedAndUnique() {
    #expect(schedule == schedule.sorted { $0.start < $1.start })
    #expect(Set(schedule.map(\.acknowledgementKey)).count == schedule.count)
  }
}
