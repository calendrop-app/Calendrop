import Foundation
import Testing

@testable import CalendropCore

@Suite struct AccountSettingsTests {
  private let work = CalendarRef(id: "work", name: "Work", isSelectedInGoogle: true)
  private let holidays = CalendarRef(id: "holidays", name: "Holidays", isSelectedInGoogle: false)

  @Test func showsTheLabelOrElseTheAddress() {
    var account = AccountSettings(email: "me@example.com", color: AccountPalette.colors[0])
    #expect(account.displayName == "me@example.com")
    account.label = "  "
    #expect(account.displayName == "me@example.com")
    account.label = "Work"
    #expect(account.displayName == "Work")
  }

  @Test func followsGoogleCalendarsSelectionUntilTheUserChooses() {
    var account = AccountSettings(email: "me@example.com", color: AccountPalette.colors[0])
    #expect(account.uses(work))
    #expect(!account.uses(holidays))

    account.setCalendar(holidays, used: true, among: [work, holidays])
    #expect(account.uses(work))
    #expect(account.uses(holidays))

    account.setCalendar(work, used: false, among: [work, holidays])
    #expect(!account.uses(work))
    #expect(account.calendarIDs == ["holidays"])
  }

  @Test func tellsWhetherAMeetingIsOnACalendarItUses() {
    var account = AccountSettings(email: "me@example.com", color: AccountPalette.colors[0])
    account.setCalendar(work, used: false, among: [work, holidays])
    func meeting(on calendarID: String) -> Meeting {
      Meeting(
        uid: calendarID, title: "t", start: .now, end: .now, joinURL: nil, htmlLink: nil, account: account.email,
        calendarID: calendarID, calendarName: calendarID)
    }
    #expect(!account.uses(meeting(on: "work"), among: [work, holidays]))
    #expect(!account.uses(meeting(on: "gone"), among: [work, holidays]))
    account.setCalendar(holidays, used: true, among: [work, holidays])
    #expect(account.uses(meeting(on: "holidays"), among: [work, holidays]))
  }

  @Test func canGoBackToGoogleCalendarsSelection() {
    var account = AccountSettings(email: "me@example.com", color: AccountPalette.colors[0])
    account.setCalendar(holidays, used: true, among: [work, holidays])
    account.calendarIDs = nil
    #expect(!account.uses(holidays))
  }
}

@Suite struct SharedConfigAccountsTests {
  @Test func readsTheOlderListOfAddresses() throws {
    let config = try JSONDecoder().decode(
      SharedConfig.self, from: Data(#"{"accounts":["a@example.com","b@example.com"]}"#.utf8))
    #expect(config.accounts.map(\.email) == ["a@example.com", "b@example.com"])
    #expect(config.accounts.map(\.color) == Array(AccountPalette.colors.prefix(2)))
  }

  @Test func roundTripsAccountSettings() throws {
    var config = SharedConfig()
    config.addAccount("a@example.com")
    config.updateAccount("a@example.com") {
      $0.label = "仕事"
      $0.calendarIDs = ["primary"]
    }
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded == config)
    #expect(decoded.account("A@example.com")?.label == "仕事")
  }

  @Test func newAccountsTakeTheFirstUnusedColour() {
    var config = SharedConfig()
    config.addAccount("a@example.com")
    config.addAccount("b@example.com")
    config.updateAccount("a@example.com") { $0.color = AccountPalette.colors[2] }
    config.addAccount("c@example.com")
    #expect(config.account("c@example.com")?.color == AccountPalette.colors[0])
  }

  @Test func coloursWrapAroundOnceAllAreTaken() {
    var config = SharedConfig()
    for i in 0...AccountPalette.colors.count { config.addAccount("u\(i)@example.com") }
    #expect(config.accounts.last?.color == AccountPalette.colors[0])
  }

  @Test func addingAnExistingAccountKeepsItsSettings() {
    var config = SharedConfig()
    config.addAccount("a@example.com")
    config.updateAccount("a@example.com") { $0.label = "Work" }
    config.addAccount("A@example.com")
    #expect(config.accounts.count == 1)
    #expect(config.account("a@example.com")?.label == "Work")
  }

  @Test func dropsMalformedEntriesInsteadOfTheWholeList() throws {
    let json = #"{"accounts":[{"email":"a@example.com","color":"nonsense"},42,{"label":"no address"}]}"#
    let config = try JSONDecoder().decode(SharedConfig.self, from: Data(json.utf8))
    #expect(config.accounts.map(\.email) == ["a@example.com"])
    #expect(config.accounts.first?.color == AccountPalette.colors[0])
  }
}
