import Foundation

/// What the menu says about the last time the calendars were read, so an empty list
/// can be told apart from one that was never read.
public enum SyncStatus {
  /// "3 calendars · updated 2 min ago", or "Not read yet" before any full read.
  public static func summary(calendars: Int, readAt: Date?, now: Date, locale: Locale = .current) -> String {
    guard let readAt else {
      return String(localized: LocalizedStringResource("Not read yet", locale: locale, bundle: .core))
    }
    let count = String(localized: LocalizedStringResource("\(calendars) calendars", locale: locale, bundle: .core))
    return "\(count) · \(updated(now.timeIntervalSince(readAt), locale: locale))"
  }

  /// "updated just now", "updated 12 min ago", "updated 3 h ago".
  public static func updated(_ elapsed: TimeInterval, locale: Locale = .current) -> String {
    let minutes = Int(elapsed / 60)
    let hours = minutes / 60
    let text =
      minutes < 1
      ? LocalizedStringResource("updated just now", locale: locale, bundle: .core)
      : minutes < 60
        ? LocalizedStringResource("updated \(minutes) min ago", locale: locale, bundle: .core)
        : LocalizedStringResource("updated \(hours) h ago", locale: locale, bundle: .core)
    return String(localized: text)
  }
}
