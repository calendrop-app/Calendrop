import Foundation

/// The words beside the menu bar icon: the next meeting and how soon it starts.
public enum MenuBarLabel {
  public static let titleLength = 24

  /// Nil when no meeting is coming, which leaves the icon alone.
  public static func text(
    meeting: Meeting?, now: Date, showTitle: Bool, locale: Locale = .current
  ) -> String? {
    guard let meeting else { return nil }
    let countdown = Countdown.short(meeting.start.timeIntervalSince(now), locale: locale)
    guard showTitle else { return countdown }
    return Countdown.truncate(meeting.title, to: titleLength) + " · " + countdown
  }
}
