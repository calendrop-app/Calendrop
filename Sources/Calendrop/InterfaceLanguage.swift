import AppKit
import CalendropCore

/// The language given to Calendrop alone. It is kept where System Settings keeps the
/// one it sets per app, so either place shows what the other chose.
@MainActor
enum InterfaceLanguage {
  private static let key = "AppleLanguages"

  /// Every language the app bundle has a translation for.
  static var available: [String] {
    Localizations.selectable(from: Bundle.main.localizations)
  }

  /// The language the interface is in, chosen by macOS at launch.
  static var current: String? { Bundle.main.preferredLocalizations.first }

  /// Nil when Calendrop follows the system's language.
  static var chosen: String? {
    get { (ownDefaults?[key] as? [String])?.first }
    set {
      // Only Calendrop's own domain: the global one holds the system's list.
      if let newValue {
        UserDefaults.standard.set([newValue], forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }
  }

  /// The language a launch shows with `chosen` given to Calendrop.
  static func atLaunch(choosing chosen: String?) -> String? {
    let system = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? [String] ?? []
    return Bundle.preferredLocalizations(from: available, forPreferences: chosen.map { [$0] } ?? system).first
  }

  /// The language named in itself, so a reader who cannot read the current
  /// interface can still find their own.
  static func nativeName(_ language: String) -> String {
    Locale(identifier: language).localizedString(forLanguageCode: language) ?? language
  }

  /// Whether Calendrop runs as an app bundle, which is what can be started again.
  static var canRelaunch: Bool { Bundle.main.bundleURL.pathExtension == "app" }

  /// Quits and starts Calendrop again, so the interface is built in the new language.
  static func relaunch() {
    // `open` would bring the running copy forward instead of starting another, so a
    // shell waits for this one to exit first.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; open \"$2\"", "relaunch",
      String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundleURL.path,
    ]
    guard (try? process.run()) != nil else { return }
    NSApp.terminate(nil)
  }

  private static var ownDefaults: [String: Any]? {
    Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
  }
}
