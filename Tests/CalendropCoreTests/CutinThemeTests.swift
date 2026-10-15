import Foundation
import Testing

@testable import CalendropCore

@Suite struct ThemeColorTests {
  @Test(arguments: ["#1A2B3C", "1a2b3c", " #1a2b3c "])
  func parsesHex(hex: String) throws {
    let color = try #require(ThemeColor(hex: hex))
    #expect(color.hex == "#1A2B3C")
  }

  @Test(arguments: ["", "#12345", "#GGGGGG", "#1234567"])
  func rejectsMalformedHex(hex: String) {
    #expect(ThemeColor(hex: hex) == nil)
  }

  @Test func clampsComponentsWhenFormatting() {
    #expect(ThemeColor(red: 1.2, green: -0.1, blue: 0.5).hex == "#FF0080")
  }

  @Test func encodesAsHexString() throws {
    let data = try JSONEncoder().encode([ThemeColor(hex: "#FFFFFF")!])
    #expect(String(decoding: data, as: UTF8.self) == ##"["#FFFFFF"]"##)
  }

  @Test func knowsWhichTextReadsOnIt() {
    #expect(ThemeColor(hex: "#FFFFFF")!.isLight)
    #expect(ThemeColor(hex: "#F5D76E")!.isLight)
    #expect(!ThemeColor(hex: "#1F6FEB")!.isLight)
    #expect(!ThemeColor(hex: "#000000")!.isLight)
  }
}

@Suite struct CutinAppearanceTests {
  @Test func defaultsToTheFirstPreset() {
    let appearance = CutinAppearance()
    #expect(appearance.style == .preset(CutinPreset.allCases[0]))
    #expect(appearance.theme == CutinPreset.allCases[0].theme)
  }

  @Test func everyPresetIsDistinct() {
    #expect(Set(CutinPreset.allCases.map(\.theme.backgroundTop)).count == CutinPreset.allCases.count)
  }

  @Test func presetSelectionUsesThePresetTheme() {
    var appearance = CutinAppearance()
    appearance.style = .preset(.daylight)
    #expect(appearance.theme == CutinPreset.daylight.theme)
  }

  @Test func customizingStartsFromTheCurrentPreset() {
    var appearance = CutinAppearance()
    appearance.style = .preset(.sunset)
    appearance.customize()
    #expect(appearance.style == .custom)
    #expect(appearance.theme == CutinPreset.sunset.theme)
  }

  @Test func customEditsSurviveSwitchingToAPresetAndBack() {
    var appearance = CutinAppearance()
    appearance.customize()
    appearance.custom.accent = ThemeColor(hex: "#00FF00")!
    appearance.style = .preset(.ocean)
    appearance.style = .custom
    #expect(appearance.theme.accent == ThemeColor(hex: "#00FF00"))
  }

  @Test func customizingAgainKeepsEarlierEdits() {
    var appearance = CutinAppearance()
    appearance.customize()
    appearance.custom.accent = ThemeColor(hex: "#00FF00")!
    appearance.customize()
    #expect(appearance.theme.accent == ThemeColor(hex: "#00FF00"))
  }

  @Test func roundTripsThroughJSON() throws {
    var appearance = CutinAppearance()
    appearance.customize()
    appearance.custom.fontDesign = .serif
    appearance.custom.backgroundOpacity = 0.8
    let decoded = try JSONDecoder().decode(CutinAppearance.self, from: JSONEncoder().encode(appearance))
    #expect(decoded == appearance)
  }

  @Test func toleratesUnknownAndMissingValues() throws {
    let json = ##"{"style":"neon","custom":{"accent":"#123456","fontDesign":"comic"}}"##
    let appearance = try JSONDecoder().decode(CutinAppearance.self, from: Data(json.utf8))
    #expect(appearance.style == .preset(CutinPreset.allCases[0]))
    #expect(appearance.custom.accent == ThemeColor(hex: "#123456"))
    #expect(appearance.custom.fontDesign == CutinPreset.allCases[0].theme.fontDesign)
    #expect(appearance.custom.backgroundTop == CutinPreset.allCases[0].theme.backgroundTop)
  }

  @Test func clampsOpacityToAReadableRange() throws {
    let json = #"{"style":"custom","custom":{"backgroundOpacity":0.1}}"#
    let appearance = try JSONDecoder().decode(CutinAppearance.self, from: Data(json.utf8))
    #expect(appearance.theme.backgroundOpacity == CutinTheme.opacityRange.lowerBound)
  }

  @Test func sharedConfigCarriesTheAppearance() throws {
    var config = SharedConfig()
    config.appearance.style = .preset(.monochrome)
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded.appearance.style == .preset(.monochrome))
    let legacy = try JSONDecoder().decode(SharedConfig.self, from: Data(#"{"leadMinutes":3}"#.utf8))
    #expect(legacy.appearance == CutinAppearance())
  }
}
