import Foundation
import Testing

@testable import CalendropCore

@Suite struct DemoCalendarTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let policy = CutinPolicy(leadTime: 2 * 60)

  private var meetings: [Meeting] { DemoCalendar.meetings(now: now, leadTime: policy.leadTime) }

  @Test func firstCutInArrivesShortlyAfterLaunch() {
    #expect(policy.meetingsToCutIn(meetings, now: now, acknowledged: []).isEmpty)
    let due = policy.meetingsToCutIn(
      meetings, now: now.addingTimeInterval(DemoCalendar.firstCutInDelay), acknowledged: [])
    #expect(due.count == 1)
  }

  @Test func anOverlappingMeetingJoinsTheShowingCutIn() {
    let later = now.addingTimeInterval(DemoCalendar.firstCutInDelay + DemoCalendar.overlapDelay)
    let due = policy.meetingsToCutIn(meetings, now: later, acknowledged: [])
    #expect(due.count == 2)
    #expect(Set(due.map(\.account)).count == 2)
  }

  @Test func followsTheConfiguredLeadTime() {
    let longLead = CutinPolicy(leadTime: 10 * 60)
    let demo = DemoCalendar.meetings(now: now, leadTime: longLead.leadTime)
    let due = longLead.meetingsToCutIn(
      demo, now: now.addingTimeInterval(DemoCalendar.firstCutInDelay), acknowledged: [])
    #expect(due.count == 1)
  }

  @Test func coversWhatTheMenuShows() {
    #expect(meetings.contains { $0.start < now && $0.end > now })
    #expect(meetings.contains { $0.joinURL == nil })
    #expect(meetings.contains { !Calendar.current.isDate($0.start, inSameDayAs: now) })
    #expect(meetings.contains { $0.title.unicodeScalars.contains { $0.value > 0x3000 } })
    #expect(Set(meetings.map(\.account)) == Set(DemoCalendar.accounts))
  }

  @Test func neverPointsAtARealMeeting() {
    #expect(meetings.compactMap(\.openURL).allSatisfy { $0.host == "example.com" })
  }

  @Test func isSortedAndUnique() {
    #expect(meetings == meetings.sorted { $0.start < $1.start })
    #expect(Set(meetings.map(\.acknowledgementKey)).count == meetings.count)
  }
}
