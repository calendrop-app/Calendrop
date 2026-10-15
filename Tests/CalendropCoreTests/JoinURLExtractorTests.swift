import Foundation
import Testing

@testable import CalendropCore

@Suite struct JoinURLExtractorTests {
  @Test func prefersHangoutLink() {
    let url = JoinURLExtractor.extract(
      hangoutLink: "https://meet.google.com/abc-defg-hij",
      videoEntryPoints: ["https://zoom.us/j/1"],
      texts: ["https://teams.microsoft.com/l/meetup-join/x"]
    )
    #expect(url == URL(string: "https://meet.google.com/abc-defg-hij"))
  }

  @Test func fallsBackToVideoEntryPoint() {
    let url = JoinURLExtractor.extract(
      hangoutLink: nil,
      videoEntryPoints: ["https://us02web.zoom.us/j/123?pwd=x"],
      texts: []
    )
    #expect(url == URL(string: "https://us02web.zoom.us/j/123?pwd=x"))
  }

  @Test(arguments: [
    ("Join: https://us02web.zoom.us/j/8123456789?pwd=abc here", "https://us02web.zoom.us/j/8123456789?pwd=abc"),
    (
      "<a href=\"https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=%7b%7d\">Join</a>",
      "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=%7b%7d"
    ),
    ("会議URL：https://meet.google.com/abc-defg-hij です", "https://meet.google.com/abc-defg-hij"),
    ("https://example.webex.com/meet/someone", "https://example.webex.com/meet/someone"),
    ("Join https://zoom.us/j/1?pwd=a&amp;uname=b now", "https://zoom.us/j/1?pwd=a&uname=b"),
  ])
  func findsKnownServiceInText(text: String, expected: String) {
    let url = JoinURLExtractor.extract(hangoutLink: nil, videoEntryPoints: [], texts: [text])
    #expect(url == URL(string: expected))
  }

  @Test func ignoresUnrelatedLinks() {
    let url = JoinURLExtractor.extract(
      hangoutLink: nil,
      videoEntryPoints: [],
      texts: ["Agenda: https://docs.google.com/document/d/xyz"]
    )
    #expect(url == nil)
  }

  @Test func searchesTextsInOrder() {
    let url = JoinURLExtractor.extract(
      hangoutLink: nil,
      videoEntryPoints: [],
      texts: [nil, "https://zoom.us/j/1", "https://meet.google.com/aaa-bbbb-ccc"].compactMap { $0 }
    )
    #expect(url == URL(string: "https://zoom.us/j/1"))
  }
}
