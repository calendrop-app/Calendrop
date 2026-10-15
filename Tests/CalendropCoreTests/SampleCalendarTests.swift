import Foundation
import Testing

@testable import CalendropCore

@Suite struct SampleCalendarTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let policy = CutinPolicy(leadTime: 2 * 60, includesMeetingsWithoutJoinLink: true)

  private var schedule: [Meeting] { SampleCalendar.meetings(now: now, accounts: SampleCalendar.accounts) }

  private func group(_ scenario: SampleCalendar.Scenario, at time: Date? = nil, acknowledged: Set<String> = [])
    -> [Meeting]
  {
    let meetings = scenario.meetings(now: now, leadTime: policy.leadTime)
    return policy.cutInGroup(meetings, now: time ?? now, acknowledged: acknowledged)
  }

  @Test func scheduleCoversWhatTheMenuShows() {
    #expect(schedule.contains { $0.start < now && $0.end > now })
    #expect(schedule.contains { $0.joinURL == nil })
    #expect(schedule.contains { !Calendar.current.isDate($0.start, inSameDayAs: now) })
    #expect(Set(schedule.map(\.account)) == Set(SampleCalendar.accounts))
  }

  @Test func everyMeetingBelongsToOneOfItsAccountsCalendars() {
    for meeting in schedule {
      #expect(SampleCalendar.calendars(for: meeting.account).map(\.id).contains(meeting.calendarID))
    }
  }

  @Test func someMeetingsSitBeyondTheMainCalendar() {
    let unticked = SampleCalendar.accounts.flatMap { SampleCalendar.calendars(for: $0) }.filter {
      !$0.isPrimary
    }
    #expect(schedule.contains { m in unticked.contains { $0.id == m.calendarID } })
  }

  @Test func startsWithTheNamedAccountsLabelled() {
    #expect(SampleCalendar.presetAccounts.map(\.email) == SampleCalendar.accounts)
    #expect(SampleCalendar.presetAccounts.allSatisfy { $0.label != nil })
    for preset in SampleCalendar.presetAccounts {
      #expect(!SampleCalendar.calendars(for: preset.email).isEmpty)
    }
  }

  @Test func signingInYieldsTheNamedSampleAccountsFirst() {
    #expect(SampleCalendar.newAccount(existing: []) == SampleCalendar.accounts[0])
    #expect(SampleCalendar.newAccount(existing: [SampleCalendar.accounts[0]]) == SampleCalendar.accounts[1])
  }

  @Test func anAddedAccountComesWithCalendarsAndMeetings() {
    let added = SampleCalendar.newAccount(existing: SampleCalendar.accounts)
    #expect(!SampleCalendar.accounts.contains(added))
    #expect(SampleCalendar.newAccount(existing: SampleCalendar.accounts + [added]) != added)
    #expect(SampleCalendar.calendars(for: added).contains { $0.isPrimary })
    #expect(SampleCalendar.meetings(now: now, accounts: [added]).allSatisfy { $0.account == added })
    #expect(!SampleCalendar.meetings(now: now, accounts: [added]).isEmpty)
  }

  @Test(arguments: SampleCalendar.Scenario.allCases)
  func scenarioIsDueTheMomentItIsAdded(scenario: SampleCalendar.Scenario) {
    #expect(!group(scenario).isEmpty)
  }

  @Test func everydaySamplesAreInEnglish() {
    let everyday = SampleCalendar.Scenario.allCases.filter { $0 != .manyScripts }
      .flatMap { $0.meetings(now: now, leadTime: 0) }
    for meeting in schedule + everyday {
      #expect(meeting.title.unicodeScalars.allSatisfy { $0.isASCII }, "\(meeting.title)")
    }
  }

  @Test func manyScriptsCoversEachWritingSystem() {
    let titles = SampleCalendar.Scenario.manyScripts.meetings(now: now, leadTime: 0).map(\.title)
    let scripts: [(String, ClosedRange<UInt32>)] = [
      ("Hiragana", 0x3040...0x309F), ("Hangul", 0xAC00...0xD7AF), ("Han", 0x4E00...0x9FFF),
      ("Arabic", 0x0600...0x06FF), ("Thai", 0x0E00...0x0E7F), ("Devanagari", 0x0900...0x097F),
      ("Emoji", 0x1F300...0x1FAFF),
    ]
    for (name, range) in scripts {
      #expect(titles.contains { $0.unicodeScalars.contains { range.contains($0.value) } }, "\(name)")
    }
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
    let first = SampleCalendar.Scenario.single.meetings(now: now, leadTime: 0)
    let second = SampleCalendar.Scenario.single.meetings(now: now.addingTimeInterval(1), leadTime: 0)
    #expect(Set(first.map(\.acknowledgementKey)).isDisjoint(with: second.map(\.acknowledgementKey)))
  }

  @Test func neverPointsAtARealMeeting() {
    let all = schedule + SampleCalendar.Scenario.allCases.flatMap { $0.meetings(now: now, leadTime: 0) }
    #expect(all.compactMap(\.openURL).allSatisfy { $0.host == "example.com" })
  }

  @Test func isSortedAndUnique() {
    #expect(schedule == schedule.sorted { $0.start < $1.start })
    #expect(Set(schedule.map(\.acknowledgementKey)).count == schedule.count)
  }
}

@Suite struct SampleMainCalendarTests {
  @Test(arguments: SampleCalendar.accounts + ["sample1@example.com"])
  func eachAccountHasOneMainCalendarNamedAfterIt(account: String) {
    let main = SampleCalendar.calendars(for: account).filter { $0.isPrimary }
    #expect(main.map(\.id) == [account])
  }
}
