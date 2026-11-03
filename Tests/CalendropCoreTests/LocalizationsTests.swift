import CalendropCore
import Testing

@Suite struct LocalizationsTests {
  @Test func listsEachLanguageOnce() {
    #expect(Localizations.selectable(from: ["en", "ja", "ja", "en"]) == ["en", "ja"])
  }

  @Test func excludesBaseAndSortsLanguageCodes() {
    #expect(Localizations.selectable(from: ["ja", "Base", "en", "Base"]) == ["en", "ja"])
  }

  @Test func preservesRegionalVariants() {
    #expect(Localizations.selectable(from: ["en-US", "en-GB", "en-US"]) == ["en-GB", "en-US"])
  }
}
