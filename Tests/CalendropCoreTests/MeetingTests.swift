import Foundation
import Testing

@testable import CalendropCore

@Suite struct MeetingOpenURLTests {
  private func meeting(join: String?, html: String? = nil, account: String = "me+work@example.com") -> Meeting {
    Meeting(
      uid: "u", title: "t", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60),
      joinURL: join.flatMap(URL.init(string:)), htmlLink: html.flatMap(URL.init(string:)), account: account,
      calendarName: "c")
  }

  private func query(_ url: URL?) -> [String: String] {
    let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
  }

  @Test func opensMeetAsTheEventsAccount() {
    let url = meeting(join: "https://meet.google.com/abc-defg-hij").openURL
    #expect(url?.host == "meet.google.com")
    #expect(url?.path == "/abc-defg-hij")
    #expect(query(url)["authuser"] == "me+work@example.com")
  }

  @Test func keepsExistingQueryItems() {
    let url = meeting(join: "https://meet.google.com/abc-defg-hij?hs=1").openURL
    #expect(query(url) == ["hs": "1", "authuser": "me+work@example.com"])
  }

  @Test func replacesAnAuthuserAlreadyPresent() {
    let url = meeting(join: "https://meet.google.com/abc-defg-hij?authuser=0").openURL
    #expect(query(url)["authuser"] == "me+work@example.com")
  }

  @Test func opensTheEventPageAsTheAccountEvenWhenThereIsAJoinLink() {
    let url = meeting(
      join: "https://meet.google.com/abc-defg-hij", html: "https://www.google.com/calendar/event?eid=xyz"
    )
    .eventURL
    #expect(url?.path == "/calendar/event")
    #expect(query(url) == ["eid": "xyz", "authuser": "me+work@example.com"])
    #expect(meeting(join: "https://meet.google.com/abc-defg-hij").eventURL == nil)
  }

  @Test func opensTheGoogleCalendarEventAsTheAccountWhenThereIsNoJoinLink() {
    let url = meeting(join: nil, html: "https://www.google.com/calendar/event?eid=xyz").openURL
    #expect(query(url) == ["eid": "xyz", "authuser": "me+work@example.com"])
  }

  @Test func leavesOtherServicesUntouched() {
    let zoom = "https://us02web.zoom.us/j/123?pwd=x"
    #expect(meeting(join: zoom).openURL == URL(string: zoom))
  }
}
