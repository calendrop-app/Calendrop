import Foundation
import Testing

@testable import CalendropCore

@Suite struct PlainTextTests {
  @Test func turnsGoogleCalendarHTMLIntoLines() {
    let html = "Agenda:<br>1. Review&nbsp;Q3<br/>2. <b>Plan</b> &amp; assign<p>Notes &lt;draft&gt;</p>"
    #expect(PlainText.fromHTML(html) == "Agenda:\n1. Review Q3\n2. Plan & assign\nNotes <draft>")
  }

  @Test func keepsTheTargetOfALink() {
    let html = #"Docs: <a href="https://example.com/doc">the plan</a>"#
    #expect(PlainText.fromHTML(html) == "Docs: the plan (https://example.com/doc)")
  }

  @Test func doesNotRepeatALinkWhoseTextIsItsTarget() {
    let html = #"<a href="https://example.com/doc">https://example.com/doc</a>"#
    #expect(PlainText.fromHTML(html) == "https://example.com/doc")
  }

  @Test func collapsesBlankLinesAndTrims() {
    #expect(PlainText.fromHTML("\n\n  first  \n\n\n\nsecond\n\n") == "first\n\nsecond")
  }

  @Test func leavesPlainTextAlone() {
    #expect(PlainText.fromHTML("会議室 3A で実施\n資料は後で共有") == "会議室 3A で実施\n資料は後で共有")
  }

  @Test func decodesNumericEntities() {
    #expect(PlainText.fromHTML("It&#39;s &#x2014; done") == "It's — done")
  }
}

@Suite struct MeetingDetailsParsingTests {
  private func parse(_ json: String) throws -> Meeting {
    try #require(
      GoogleCalendarParser.meetings(
        fromEvents: Data(json.utf8), account: "me@example.com",
        calendar: CalendarRef(id: "c", name: "Work", isPrimary: true)
      ).first)
  }

  @Test func readsPlaceNotesOrganizerAndPeople() throws {
    let meeting = try parse(
      """
      {"items":[{"id":"e","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},
        "location":"Room 3A","description":"Agenda:<br>Review",
        "organizer":{"email":"boss@example.com","displayName":"Boss"},
        "attendees":[
          {"email":"me@example.com","self":true,"responseStatus":"accepted"},
          {"email":"aki@example.com","displayName":"Aki","responseStatus":"accepted"},
          {"email":"ken@example.com","responseStatus":"tentative"},
          {"email":"room@resource.calendar.google.com","displayName":"Room 3A","resource":true},
          {"email":"no@example.com","displayName":"No","responseStatus":"declined"}
        ]}]}
      """)
    #expect(meeting.location == "Room 3A")
    #expect(meeting.notes == "Agenda:\nReview")
    #expect(meeting.organizer == "Boss")
    #expect(meeting.attendees == ["Aki", "ken@example.com"])
  }

  @Test func leavesDetailsEmptyWhenTheEventHasNone() throws {
    let meeting = try parse(
      #"{"items":[{"id":"e","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},"description":"  "}]}"#
    )
    #expect(meeting.location == nil)
    #expect(meeting.notes == nil)
    #expect(meeting.organizer == nil)
    #expect(meeting.attendees.isEmpty)
  }

  @Test func doesNotNameTheUserAsOrganizerOfTheirOwnMeeting() throws {
    let meeting = try parse(
      #"{"items":[{"id":"e","start":{"dateTime":"2026-10-16T01:00:00Z"},"end":{"dateTime":"2026-10-16T02:00:00Z"},"organizer":{"email":"me@example.com","self":true}}]}"#
    )
    #expect(meeting.organizer == nil)
  }
}

@Suite struct AttendeeSummaryTests {
  private func summary(_ names: [String]) -> String? {
    Meeting(
      uid: "u", title: "t", start: .now, end: .now, joinURL: nil, htmlLink: nil, account: "a", calendarName: "c",
      attendees: names
    ).attendeeSummary
  }

  @Test(
    arguments: [
      ([], nil),
      (["Aki"], "With Aki"),
      (["Aki", "Ken", "Lee"], "With Aki, Ken, Lee"),
      (["Aki", "Ken", "Lee", "Rin"], "With Aki, Ken, Lee and 1 other"),
      (["Aki", "Ken", "Lee", "Rin", "Mika"], "With Aki, Ken, Lee and 2 others"),
    ] as [([String], String?)])
  func namesTheFirstFewAndCountsTheRest(names: [String], expected: String?) {
    #expect(summary(names) == expected)
  }
}

@Suite struct ResponseLabelTests {
  @Test(
    arguments: [
      (Meeting.Response.accepted, nil),
      (.tentative, "Maybe"),
      (.unanswered, "Not answered"),
    ] as [(Meeting.Response, String?)])
  func marksOnlyMeetingsNotAccepted(response: Meeting.Response, expected: String?) {
    #expect(response.label == expected)
  }
}
