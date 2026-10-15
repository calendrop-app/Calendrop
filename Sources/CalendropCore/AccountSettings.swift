import Foundation

/// How the user has set up one Google account, shared between their Macs.
public struct AccountSettings: Codable, Equatable, Sendable, Identifiable {
  public var email: String
  /// Shown instead of the address wherever the account is named.
  public var label: String?
  public var color: ThemeColor
  /// The calendars Calendrop reads, or nil to follow what is ticked in Google Calendar.
  public var calendarIDs: [String]?

  public init(email: String, label: String? = nil, color: ThemeColor, calendarIDs: [String]? = nil) {
    self.email = email.lowercased()
    self.label = label
    self.color = color
    self.calendarIDs = calendarIDs
  }

  public var id: String { email }

  public var displayName: String {
    let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? email : trimmed
  }

  public func uses(_ calendar: CalendarRef) -> Bool {
    calendarIDs.map { $0.contains(calendar.id) } ?? calendar.isSelectedInGoogle
  }

  /// Whether `meeting` sits on a calendar this account uses; a calendar no longer
  /// among `calendars` counts as not used.
  public func uses(_ meeting: Meeting, among calendars: [CalendarRef]) -> Bool {
    calendars.first { $0.id == meeting.calendarID }.map(uses) ?? false
  }

  /// Turns one calendar on or off. The first choice starts from Google Calendar's
  /// selection, so choosing one calendar never silently drops the others.
  public mutating func setCalendar(_ calendar: CalendarRef, used: Bool, among all: [CalendarRef]) {
    var chosen = Set(calendarIDs ?? all.filter(\.isSelectedInGoogle).map(\.id))
    if used { chosen.insert(calendar.id) } else { chosen.remove(calendar.id) }
    let known = all.map(\.id)
    calendarIDs = known.filter(chosen.contains) + chosen.subtracting(known).sorted()
  }
}

public enum AccountPalette {
  public static let colors: [ThemeColor] = [
    "#4F7DF3", "#E5484D", "#30A46C", "#F5A524", "#8E4EC6", "#12A594", "#E54D2E", "#D6409F",
  ].map { ThemeColor(hex: $0)! }

  /// The first colour no account uses yet, or the next one round the palette.
  public static func color(after used: [ThemeColor]) -> ThemeColor {
    colors.first { !used.contains($0) } ?? colors[used.count % colors.count]
  }
}
