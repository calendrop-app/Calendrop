import Foundation

public struct CalendarRef: Hashable, Sendable {
  public var id: String
  public var name: String
}

/// Turns Google Calendar API v3 responses into `Meeting`s.
public enum GoogleCalendarParser {
  /// Event types that occupy the calendar but are not something to join.
  private static let ignoredEventTypes: Set<String> = ["outOfOffice", "focusTime", "workingLocation", "birthday"]

  public static func meetings(fromEvents data: Data, account: String, calendarName: String) throws -> [Meeting] {
    let response = try JSONDecoder().decode(EventsResponse.self, from: data)
    return response.items.compactMap { event in
      guard event.status != "cancelled",
        !ignoredEventTypes.contains(event.eventType ?? ""),
        let start = event.start.dateTime.flatMap(parseDate),
        let end = event.end.dateTime.flatMap(parseDate)
      else { return nil }
      if event.attendees?.contains(where: { $0.isSelf == true && $0.responseStatus == "declined" }) == true {
        return nil
      }
      let videoEntryPoints = (event.conferenceData?.entryPoints ?? [])
        .filter { $0.entryPointType == "video" }
        .compactMap(\.uri)
      return Meeting(
        uid: event.iCalUID ?? event.id,
        title: event.summary.flatMap { $0.isEmpty ? nil : $0 } ?? "(No title)",
        start: start,
        end: end,
        joinURL: JoinURLExtractor.extract(
          hangoutLink: event.hangoutLink,
          videoEntryPoints: videoEntryPoints,
          texts: [event.location, event.description].compactMap { $0 }
        ),
        htmlLink: event.htmlLink.flatMap(URL.init(string:)),
        account: account,
        calendarName: calendarName
      )
    }
  }

  /// The continuation token of any paged Calendar API list response.
  public static func nextPageToken(from data: Data) throws -> String? {
    try JSONDecoder().decode(PageInfo.self, from: data).nextPageToken
  }

  /// The calendars the user has ticked in Google Calendar's sidebar.
  public static func calendars(fromCalendarList data: Data) throws -> [CalendarRef] {
    try JSONDecoder().decode(CalendarListResponse.self, from: data).items
      .filter { $0.selected == true }
      .map { CalendarRef(id: $0.id, name: $0.summaryOverride ?? $0.summary ?? $0.id) }
  }

  static func parseDate(_ string: String) -> Date? {
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let date = plain.date(from: string) { return date }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: string)
  }
}

private struct PageInfo: Decodable {
  var nextPageToken: String?
}

private struct EventsResponse: Decodable {
  var items: [Event]

  struct Event: Decodable {
    var id: String
    var iCalUID: String?
    var status: String?
    var eventType: String?
    var summary: String?
    var description: String?
    var location: String?
    var htmlLink: String?
    var hangoutLink: String?
    var start: EventTime
    var end: EventTime
    var attendees: [Attendee]?
    var conferenceData: ConferenceData?
  }

  struct EventTime: Decodable {
    var dateTime: String?
  }

  struct Attendee: Decodable {
    var isSelf: Bool?
    var responseStatus: String?

    enum CodingKeys: String, CodingKey {
      case isSelf = "self"
      case responseStatus
    }
  }

  struct ConferenceData: Decodable {
    var entryPoints: [EntryPoint]?
  }

  struct EntryPoint: Decodable {
    var entryPointType: String?
    var uri: String?
  }
}

private struct CalendarListResponse: Decodable {
  var items: [Entry]

  struct Entry: Decodable {
    var id: String
    var summary: String?
    var summaryOverride: String?
    var selected: Bool?
  }
}
