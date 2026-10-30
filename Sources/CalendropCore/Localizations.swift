/// An app bundle's localizations, as a choice of interface language.
public enum Localizations {
  /// The language codes a user can choose, each once and in order.
  public static func selectable(from localizations: [String]) -> [String] {
    // A language can appear in both Info.plist and a compiled translation folder.
    Set(localizations.filter { $0 != "Base" }).sorted()
  }
}
