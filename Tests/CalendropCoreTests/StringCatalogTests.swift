import CalendropCore
import Foundation
import Testing

/// Both String Catalogs, the app's included: this is the only test target, and a
/// catalog is data that needs no code of the app to check.
@Suite struct StringCatalogTests {
  private static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  static let catalogs = ["Sources/CalendropCore/Localizable.xcstrings", "Resources/Localizable.xcstrings"]

  private struct Catalog: Decodable {
    var sourceLanguage: String
    var strings: [String: Entry]
  }

  private struct Entry: Decodable {
    var extractionState: String?
    var shouldTranslate: Bool?
    var localizations: [String: Localization]?
  }

  private struct Localization: Decodable {
    var stringUnit: StringUnit?
    var variations: [String: [String: Localization]]?

    /// Every form a translator has to write, plural forms included.
    var units: [StringUnit] {
      [stringUnit].compactMap { $0 } + (variations ?? [:]).values.flatMap { $0.values.flatMap(\.units) }
    }
  }

  private struct StringUnit: Decodable {
    var state: String
    var value: String
  }

  private func load(_ path: String) throws -> Catalog {
    try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: Self.root.appendingPathComponent(path)))
  }

  @Test(arguments: catalogs)
  func everyStringIsTranslatedIntoJapanese(path: String) throws {
    let catalog = try load(path)
    #expect(catalog.sourceLanguage == "en")
    let untranslated = catalog.strings.filter { _, entry in
      guard entry.shouldTranslate != false else { return false }
      let units = entry.localizations?["ja"]?.units ?? []
      return units.isEmpty || units.contains { $0.state != "translated" || $0.value.isEmpty }
    }
    #expect(untranslated.isEmpty, "untranslated: \(untranslated.keys.sorted())")
  }

  @Test(arguments: catalogs)
  func holdsNoStringTheSourceNoLongerUses(path: String) throws {
    let stale = try load(path).strings.filter { $0.value.extractionState == "stale" }
    #expect(stale.isEmpty, "stale (run just l10n): \(stale.keys.sorted())")
  }

  @Test(arguments: ["en", "ja"])
  func namesEveryPresetAndScenarioApart(language: String) {
    let locale = Locale(identifier: language)
    #expect(Set(CutinPreset.allCases.map { $0.title(locale: locale) }).count == CutinPreset.allCases.count)
    let scenarios = SampleCalendar.Scenario.allCases
    #expect(Set(scenarios.map { $0.title(locale: locale) }).count == scenarios.count)
  }

  @Test func namesAPresetInJapanese() {
    #expect(CutinPreset.midnight.title(locale: Locale(identifier: "ja")) == "ミッドナイト")
  }
}
