import Foundation

/// What the menu says about the last time the calendars were read, so an empty list
/// can be told apart from one that was never read.
public enum SyncStatus {
  /// "3 calendars · updated 2 min ago", or "Not read yet" before any full read.
  public static func summary(calendars: Int, readAt: Date?, now: Date) -> String {
    guard let readAt else { return "Not read yet" }
    let noun = calendars == 1 ? "calendar" : "calendars"
    return "\(calendars) \(noun) · \(updated(now.timeIntervalSince(readAt)))"
  }

  /// "updated just now", "updated 12 min ago", "updated 3 h ago".
  public static func updated(_ elapsed: TimeInterval) -> String {
    let minutes = Int(elapsed / 60)
    if minutes < 1 { return "updated just now" }
    if minutes < 60 { return "updated \(minutes) min ago" }
    return "updated \(minutes / 60) h ago"
  }
}
