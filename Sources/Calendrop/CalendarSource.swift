import CalendropCore
import Foundation

/// Where accounts, calendars and meetings come from. The rest of the app works the
/// same whichever source it is given; the app picks one at launch.
@MainActor
protocol CalendarSource: AnyObject {
  /// Something the user should know about the source itself, shown in the menu and settings.
  var notice: String? { get }
  /// Accounts to set up when there are none yet.
  var presetAccounts: [(email: String, label: String?)] { get }
  /// Whether this Mac can read `account` without the user signing in again.
  func isSignedIn(_ account: String) -> Bool
  /// Signs an account in and returns its address. `existing` lists the accounts
  /// already set up.
  func signIn(hint: String?, existing: [String]) async throws -> String
  /// Drops what this Mac holds for `account`.
  func forget(_ account: String)
  /// Every calendar the account offers, with its main calendar marked.
  func calendars(account: String) async throws -> [CalendarRef]
  /// Every meeting between `from` and `to` on `calendars`.
  func meetings(account: String, calendars: [CalendarRef], from: Date, to: Date) async throws -> [Meeting]
}

/// Sample accounts for a build without Google sign-in: signing in skips the browser
/// and yields a sample address, and every account reads `SampleCalendar`.
@MainActor
final class SampleCalendarSource: CalendarSource {
  /// The sample schedule is laid out from launch so it stays put between refreshes.
  private let startedAt = Date()

  let notice: String? =
    "This build of Calendrop has no Google sign-in, so its accounts are samples with sample calendars and meetings. Add Account adds more. Nothing is saved; they are forgotten when Calendrop quits."

  var presetAccounts: [(email: String, label: String?)] { SampleCalendar.presetAccounts }

  func isSignedIn(_ account: String) -> Bool { true }

  func signIn(hint: String?, existing: [String]) async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return hint ?? SampleCalendar.newAccount(existing: existing)
  }

  func forget(_ account: String) {}

  func calendars(account: String) async throws -> [CalendarRef] {
    SampleCalendar.calendars(for: account)
  }

  func meetings(account: String, calendars: [CalendarRef], from: Date, to: Date) async throws -> [Meeting] {
    let ids = Set(calendars.map(\.id))
    return SampleCalendar.meetings(now: startedAt, accounts: [account]).filter {
      ids.contains($0.calendarID) && $0.end > from && $0.start < to
    }
  }
}
