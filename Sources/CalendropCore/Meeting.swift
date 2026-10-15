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
  public var calendarName: String

  public init(
    uid: String, title: String, start: Date, end: Date, joinURL: URL?, htmlLink: URL?, account: String,
    calendarName: String
  ) {
    self.uid = uid
    self.title = title
    self.start = start
    self.end = end
    self.joinURL = joinURL
    self.htmlLink = htmlLink
    self.account = account
    self.calendarName = calendarName
  }

  public var id: String { acknowledgementKey }

  /// Identifies one occurrence of a meeting. Recurring events share a UID, so the
  /// start time is part of the key.
  public var acknowledgementKey: String { "\(uid)|\(Int(start.timeIntervalSince1970))" }

  /// The URL a "join" action opens: the conference link, or the event page when there is none.
  public var openURL: URL? { joinURL ?? htmlLink }

  /// Combines the meetings of several accounts into one start-ordered list.
  ///
  /// An event the user was invited to from more than one account appears once. The
  /// copy that carries a join URL wins; otherwise the first account's copy does.
  public static func merge(_ lists: [[Meeting]]) -> [Meeting] {
    var byKey: [String: Meeting] = [:]
    var order: [String] = []
    for meeting in lists.joined() {
      let key = meeting.acknowledgementKey
      if let existing = byKey[key] {
        if existing.joinURL == nil, meeting.joinURL != nil { byKey[key] = meeting }
      } else {
        byKey[key] = meeting
        order.append(key)
      }
    }
    return order.compactMap { byKey[$0] }.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
  }
}
