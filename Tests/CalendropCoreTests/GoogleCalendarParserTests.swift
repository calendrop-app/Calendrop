import Foundation
import Testing

@testable import CalendropCore

@Suite struct GoogleCalendarParserTests {
  private func parse(_ json: String, language: String = "en") throws -> [Meeting] {
    try GoogleCalendarParser.meetings(
      fromEvents: Data(json.utf8), account: "me@example.com",
      calendar: CalendarRef(id: "work-calendar", name: "Work", isPrimary: true),
      locale: Locale(identifier: language))
  }

  @Test func parsesTimedEvent() throws {
    let meetings = try parse(
      """
      {"items":[{
        "id":"e1","iCalUID":"uid1@google.com","status":"confirmed","summary":"週次定例",
        "htmlLink":"https://www.google.com/calendar/event?eid=1",
        "hangoutLink":"https://meet.google.com/abc-defg-hij",
        "start":{"dateTime":"2026-10-16T10:00:00+09:00"},
        "end":{"dateTime":"2026-10-16T10:30:00+09:00"}
      }]}
      """)
    #expect(meetings.count == 1)
    let m = try #require(meetings.first)
    #expect(m.title == "週次定例")
    #expect(m.start == Date(timeIntervalSince1970: 1_792_112_400))
    #expect(m.end.timeIntervalSince(m.start) == 30 * 60)
    #expect(m.joinURL == URL(string: "https://meet.google.com/abc-defg-hij"))
    #expect(m.htmlLink == URL(string: "https://www.google.com/calendar/event?eid=1"))
    #expect(m.account == "me@example.com")
    #expect(m.calendarName == "Work")
    #expect(m.calendarID == "work-calendar")
    #expect(m.uid == "uid1@google.com")
  }

  @Test func acceptsFractionalSecondsAndZulu() throws {
    let meetings = try parse(
      """
      {"items":[{"id":"e1","start":{"dateTime":"2026-10-16T01:00:00.000Z"},
                 "end":{"dateTime":"2026-10-16T01:30:00Z"}}]}
      """)
    #expect(meetings.first?.start == Date(timeIntervalSince1970: 1_792_112_400))
  }

  @Test(arguments: [("en", "(No title)"), ("ja", "（タイトルなし）")])
  func usesPlaceholderForMissingTitle(language: String, placeholder: String) throws {
    let meetings = try parse(
      """
      {"items":[{"id":"e1","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T01:30:00Z"}}]}
      """, language: language)
    #expect(meetings.first?.title == placeholder)
    #expect(meetings.first?.uid == "e1")
  }

  @Test func skipsAllDayCancelledDeclinedAndNonMeetingEvents() throws {
    let meetings = try parse(
      """
      {"items":[
        {"id":"allday","start":{"date":"2026-10-16"},"end":{"date":"2026-10-17"}},
        {"id":"cancelled","status":"cancelled","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"}},
        {"id":"declined","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "attendees":[{"email":"me@example.com","self":true,"responseStatus":"declined"},{"email":"x@example.com","responseStatus":"accepted"}]},
        {"id":"ooo","eventType":"outOfOffice","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"}},
        {"id":"focus","eventType":"focusTime","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"}},
        {"id":"wl","eventType":"workingLocation","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"}},
        {"id":"ok","eventType":"default","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "attendees":[{"email":"me@example.com","self":true,"responseStatus":"needsAction"}]}
      ]}
      """)
    #expect(meetings.map(\.uid) == ["ok"])
  }

  @Test func readsTheUsersResponse() throws {
    let meetings = try parse(
      """
      {"items":[
        {"id":"accepted","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "attendees":[{"email":"me@example.com","self":true,"responseStatus":"accepted"}]},
        {"id":"tentative","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "attendees":[{"email":"me@example.com","self":true,"responseStatus":"tentative"}]},
        {"id":"unanswered","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "attendees":[{"email":"me@example.com","self":true,"responseStatus":"needsAction"},{"email":"x@example.com","responseStatus":"accepted"}]},
        {"id":"own","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"}}
      ]}
      """)
    #expect(meetings.map(\.response) == [.accepted, .tentative, .unanswered, .accepted])
  }

  @Test func extractsJoinURLFromConferenceDataAndDescription() throws {
    let meetings = try parse(
      """
      {"items":[
        {"id":"conf","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "conferenceData":{"entryPoints":[{"entryPointType":"phone","uri":"tel:+1"},{"entryPointType":"video","uri":"https://zoom.us/j/9"}]}},
        {"id":"desc","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
         "location":"Room A","description":"Join https://teams.microsoft.com/l/meetup-join/abc"}
      ]}
      """)
    #expect(meetings[0].joinURL == URL(string: "https://zoom.us/j/9"))
    #expect(meetings[1].joinURL == URL(string: "https://teams.microsoft.com/l/meetup-join/abc"))
  }

  @Test func parsesNextPageTokenOfAnyListResponse() throws {
    let events = Data(#"{"items":[{"id":"e","start":{},"end":{}}],"nextPageToken":"abc"}"#.utf8)
    #expect(try GoogleCalendarParser.nextPageToken(from: events) == "abc")
    let calendarList = Data(#"{"items":[{"id":"c"}],"nextPageToken":"def"}"#.utf8)
    #expect(try GoogleCalendarParser.nextPageToken(from: calendarList) == "def")
    #expect(try GoogleCalendarParser.nextPageToken(from: Data(#"{"items":[]}"#.utf8)) == nil)
  }

  @Test func marksTheMainCalendarEvenWhenGoogleHidesIt() throws {
    let calendars = try GoogleCalendarParser.calendars(
      fromCalendarList: Data(#"{"items":[{"id":"me@example.com","primary":true}]}"#.utf8))
    #expect(calendars.map(\.isPrimary) == [true])
  }

  @Test func parsesEveryCalendarWithItsGoogleSelection() throws {
    let calendars = try GoogleCalendarParser.calendars(
      fromCalendarList: Data(
        """
        {"items":[
          {"id":"me@example.com","summary":"me@example.com","primary":true,"selected":true},
          {"id":"team#holiday@group.v.calendar.google.com","summary":"Holidays"},
          {"id":"team@group.calendar.google.com","summary":"Team","summaryOverride":"チーム","selected":true}
        ]}
        """.utf8))
    #expect(
      calendars.map(\.id) == [
        "me@example.com", "team#holiday@group.v.calendar.google.com", "team@group.calendar.google.com",
      ])
    #expect(calendars.map(\.name) == ["me@example.com", "Holidays", "チーム"])
    #expect(calendars.map(\.isPrimary) == [true, false, false])
  }
}

@Suite struct PrimaryCalendarTests {
  @Test func readsTheAccountAddressFromItsMainCalendar() throws {
    let entry = Data(#"{"id":"Me@Example.com","summary":"Me","primary":true}"#.utf8)
    #expect(try GoogleCalendarParser.accountAddress(fromPrimaryCalendar: entry) == "me@example.com")
  }

  @Test func refusesAnEntryThatIsNotTheMainCalendar() {
    let entry = Data(#"{"id":"team@group.calendar.google.com","summary":"Team"}"#.utf8)
    #expect(throws: (any Error).self) { try GoogleCalendarParser.accountAddress(fromPrimaryCalendar: entry) }
  }
}
