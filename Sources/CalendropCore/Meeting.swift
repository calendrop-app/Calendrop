import Foundation

public struct Meeting: Identifiable, Hashable, Sendable {
  /// iCalendar UID, shared by every copy of the same event across calendars and accounts.
  public var uid: String
  public var title: String
  public var start: Date
  public var end: Date
  public var joinURL: URL?
  public var htmlLink: URL?
  public var account: String
  public var calendarID: String
  public var calendarName: String
  public var location: String?
  /// The description as plain text.
  public var notes: String?
  /// Who invited the user; nil when it is the user's own meeting.
  public var organizer: String?
  /// Everyone else invited who has not declined, by name where Google has one.
  public var attendees: [String]
  /// How the user answered the invitation; a meeting nobody invited them to is accepted.
  public var response: Response

  /// Ordered from the least to the most committed. A declined meeting is never shown,
  /// so it has no case.
  public enum Response: Int, Comparable, Sendable {
    case unanswered, tentative, accepted

    public static func < (a: Response, b: Response) -> Bool { a.rawValue < b.rawValue }

    /// What marks a meeting not yet accepted; nil for an accepted one, which needs no mark.
    public var label: String? {
      switch self {
      case .accepted: nil
      case .tentative: "Maybe"
      case .unanswered: "Not answered"
      }
    }
  }

  public init(
    uid: String, title: String, start: Date, end: Date, joinURL: URL?, htmlLink: URL?, account: String,
    calendarID: String = "", calendarName: String, location: String? = nil, notes: String? = nil,
    organizer: String? = nil, attendees: [String] = [], response: Response = .accepted
  ) {
    self.uid = uid
    self.title = title
    self.start = start
    self.end = end
    self.joinURL = joinURL
    self.htmlLink = htmlLink
    self.account = account
    self.calendarID = calendarID
    self.calendarName = calendarName
    self.location = location
    self.notes = notes
    self.organizer = organizer
    self.attendees = attendees
    self.response = response
  }

  public var id: String { acknowledgementKey }

  /// Identifies one occurrence of a meeting. Recurring events share a UID, so the
  /// start time is part of the key.
  public var acknowledgementKey: String { "\(uid)|\(Int(start.timeIntervalSince1970))" }

  /// The URL a "join" action opens: the conference link, or the event page when there is none.
  ///
  /// Google links carry the event's account as `authuser`, so a browser signed in to
  /// several Google accounts opens them as the right one instead of its default.
  public var openURL: URL? {
    (joinURL ?? htmlLink).map(asAccount)
  }

  /// The event's page in Google Calendar, opened as the event's account.
  public var eventURL: URL? {
    htmlLink.map(asAccount)
  }

  private func asAccount(_ url: URL) -> URL {
    guard Self.googleHosts.contains(url.host ?? ""),
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return url }
    var items = (components.queryItems ?? []).filter { $0.name != "authuser" }
    items.append(URLQueryItem(name: "authuser", value: account))
    components.queryItems = items
    // URLComponents leaves "+" alone, but Google decodes it as a space.
    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return components.url ?? url
  }

  private static let googleHosts: Set<String> = ["meet.google.com", "calendar.google.com", "www.google.com"]

  /// "With Aki, Ken, Lee and 2 others", or nil when nobody else is invited.
  public var attendeeSummary: String? {
    guard !attendees.isEmpty else { return nil }
    let shown = attendees.prefix(3).joined(separator: ", ")
    let rest = attendees.count - 3
    return rest > 0 ? "With \(shown) and \(rest) other\(rest == 1 ? "" : "s")" : "With \(shown)"
  }

  public func overlaps(_ other: Meeting) -> Bool {
    start < other.end && other.start < end
  }

  /// Combines the meetings of several accounts into one start-ordered list.
  ///
  /// An event the user was invited to from more than one account appears once. The
  /// copy that carries a join URL wins; otherwise the first account's copy does. It
  /// keeps the firmest response any account gave, since accepting from one account
  /// is attending.
  public static func merge(_ lists: [[Meeting]]) -> [Meeting] {
    var byKey: [String: Meeting] = [:]
    var order: [String] = []
    for meeting in lists.joined() {
      let key = meeting.acknowledgementKey
      if let existing = byKey[key] {
        var kept = existing.joinURL == nil && meeting.joinURL != nil ? meeting : existing
        kept.response = max(existing.response, meeting.response)
        byKey[key] = kept
      } else {
        byKey[key] = meeting
        order.append(key)
      }
    }
    return order.compactMap { byKey[$0] }.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
  }
}
