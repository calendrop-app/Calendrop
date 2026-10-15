import Foundation

public struct CalendarRef: Hashable, Sendable, Identifiable {
  public var id: String
  public var name: String
  /// The account's own calendar, whose ID is its address; the only one an account
  /// reads until the user chooses others.
  public var isPrimary: Bool

  public init(id: String, name: String, isPrimary: Bool) {
    self.id = id
    self.name = name
    self.isPrimary = isPrimary
  }
}

/// Turns Google Calendar API v3 responses into `Meeting`s.
public enum GoogleCalendarParser {
  /// Event types that occupy the calendar but are not something to join.
  private static let ignoredEventTypes: Set<String> = ["outOfOffice", "focusTime", "workingLocation", "birthday"]

  public static func meetings(fromEvents data: Data, account: String, calendar: CalendarRef) throws -> [Meeting] {
    let response = try JSONDecoder().decode(EventsResponse.self, from: data)
    return response.items.compactMap { event in
      guard event.status != "cancelled",
        !ignoredEventTypes.contains(event.eventType ?? ""),
        let start = event.start.dateTime.flatMap(parseDate),
        let end = event.end.dateTime.flatMap(parseDate)
      else { return nil }
      let response: Meeting.Response
      switch event.attendees?.first(where: { $0.isSelf == true })?.responseStatus {
      case "declined": return nil
      case "tentative": response = .tentative
      case "needsAction": response = .unanswered
      default: response = .accepted
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
        calendarID: calendar.id,
        calendarName: calendar.name,
        location: event.location.flatMap(nonEmpty),
        notes: event.description.map(PlainText.fromHTML).flatMap(nonEmpty),
        organizer: event.organizer.flatMap { $0.isSelf == true ? nil : nonEmpty($0.displayName ?? $0.email ?? "") },
        attendees: (event.attendees ?? [])
          .filter { $0.isSelf != true && $0.resource != true && $0.responseStatus != "declined" }
          .compactMap { nonEmpty($0.displayName ?? $0.email ?? "") },
        response: response
      )
    }
  }

  private static func nonEmpty(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// The continuation token of any paged Calendar API list response.
  public static func nextPageToken(from data: Data) throws -> String? {
    try JSONDecoder().decode(PageInfo.self, from: data).nextPageToken
  }

  /// The account's address: the ID of its main calendar, which every Google
  /// account has and cannot delete.
  public static func accountAddress(fromPrimaryCalendar data: Data) throws -> String {
    let entry = try JSONDecoder().decode(CalendarListResponse.Entry.self, from: data)
    guard entry.primary == true else {
      throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not the main calendar"))
    }
    return entry.id.lowercased()
  }

  /// Every calendar of the account, with its main calendar marked.
  public static func calendars(fromCalendarList data: Data) throws -> [CalendarRef] {
    try JSONDecoder().decode(CalendarListResponse.self, from: data).items.map {
      CalendarRef(
        id: $0.id, name: $0.summaryOverride ?? $0.summary ?? $0.id, isPrimary: $0.primary == true)
    }
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
    var organizer: Attendee?
    var conferenceData: ConferenceData?
  }

  struct EventTime: Decodable {
    var dateTime: String?
  }

  struct Attendee: Decodable {
    var email: String?
    var displayName: String?
    var isSelf: Bool?
    var resource: Bool?
    var responseStatus: String?

    enum CodingKeys: String, CodingKey {
      case email, displayName, resource, responseStatus
      case isSelf = "self"
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
    var primary: Bool?
  }
}
