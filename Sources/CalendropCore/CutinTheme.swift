import Foundation

/// An sRGB colour, stored as `#RRGGBB` so the shared config stays hand-editable.
public struct ThemeColor: Codable, Hashable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  public init?(hex: String) {
    var digits = hex.trimmingCharacters(in: .whitespaces)
    if digits.hasPrefix("#") { digits.removeFirst() }
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }

  public var hex: String {
    func byte(_ c: Double) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
  }

  /// Whether dark text reads better on this colour than white text (WCAG relative luminance).
  public var isLight: Bool {
    func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) > 0.179
  }

  public init(from decoder: Decoder) throws {
    let string = try decoder.singleValueContainer().decode(String.self)
    guard let color = ThemeColor(hex: string) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Not #RRGGBB: \(string)"))
    }
    self = color
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(hex)
  }
}

public enum CutinFontDesign: String, Codable, CaseIterable, Sendable {
  case standard, rounded, serif, monospaced
}

/// How a cut-in looks.
public struct CutinTheme: Codable, Equatable, Sendable {
  public var backgroundTop: ThemeColor
  public var backgroundBottom: ThemeColor
  /// Below this the work underneath shows through enough to compete with the cut-in.
  public static let opacityRange: ClosedRange<Double> = 0.6...1
  public var backgroundOpacity: Double {
    didSet {
      backgroundOpacity = min(max(backgroundOpacity, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
    }
  }
  public var text: ThemeColor
  public var accent: ThemeColor
  public var fontDesign: CutinFontDesign

  public init(
    backgroundTop: ThemeColor, backgroundBottom: ThemeColor, backgroundOpacity: Double, text: ThemeColor,
    accent: ThemeColor, fontDesign: CutinFontDesign
  ) {
    self.backgroundTop = backgroundTop
    self.backgroundBottom = backgroundBottom
    self.backgroundOpacity = min(max(backgroundOpacity, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
    self.text = text
    self.accent = accent
    self.fontDesign = fontDesign
  }

  /// Missing or unreadable values fall back to the first preset's.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = CutinPreset.allCases[0].theme
    func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
      (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
    self.init(
      backgroundTop: value(.backgroundTop, base.backgroundTop),
      backgroundBottom: value(.backgroundBottom, base.backgroundBottom),
      backgroundOpacity: value(.backgroundOpacity, base.backgroundOpacity),
      text: value(.text, base.text),
      accent: value(.accent, base.accent),
      fontDesign: value(.fontDesign, base.fontDesign))
  }
}

public enum CutinPreset: String, CaseIterable, Codable, Sendable {
  case midnight, daylight, sunset, ocean, monochrome

  public var title: String {
    switch self {
    case .midnight: "Midnight"
    case .daylight: "Daylight"
    case .sunset: "Sunset"
    case .ocean: "Ocean"
    case .monochrome: "Monochrome"
    }
  }

  public var theme: CutinTheme {
    func c(_ hex: String) -> ThemeColor { ThemeColor(hex: hex)! }
    return switch self {
    case .midnight:
      CutinTheme(
        backgroundTop: c("#1A1738"), backgroundBottom: c("#050509"), backgroundOpacity: 0.96, text: c("#FFFFFF"),
        accent: c("#4F7DF3"), fontDesign: .rounded)
    case .daylight:
      CutinTheme(
        backgroundTop: c("#F7F5EF"), backgroundBottom: c("#E4E0D6"), backgroundOpacity: 0.97, text: c("#1D2433"),
        accent: c("#D9502E"), fontDesign: .standard)
    case .sunset:
      CutinTheme(
        backgroundTop: c("#FF7A59"), backgroundBottom: c("#6A1B4D"), backgroundOpacity: 0.95, text: c("#FFFFFF"),
        accent: c("#FFD166"), fontDesign: .rounded)
    case .ocean:
      CutinTheme(
        backgroundTop: c("#0B3D5C"), backgroundBottom: c("#021622"), backgroundOpacity: 0.95, text: c("#E6F4FF"),
        accent: c("#2EC4B6"), fontDesign: .standard)
    case .monochrome:
      CutinTheme(
        backgroundTop: c("#000000"), backgroundBottom: c("#111111"), backgroundOpacity: 1, text: c("#FFFFFF"),
        accent: c("#FFFFFF"), fontDesign: .monospaced)
    }
  }
}

/// The user's choice: one of the presets, or their own theme.
public struct CutinAppearance: Codable, Equatable, Sendable {
  public enum Style: Equatable, Sendable {
    case preset(CutinPreset)
    case custom
  }

  public var style: Style = .preset(CutinPreset.allCases[0])
  /// Kept while a preset is selected, so switching back to custom restores it.
  public var custom: CutinTheme = CutinPreset.allCases[0].theme

  public init() {}

  public var theme: CutinTheme {
    switch style {
    case .preset(let preset): preset.theme
    case .custom: custom
    }
  }

  /// Switches to a custom theme that starts as a copy of the selected preset.
  public mutating func customize() {
    guard case .preset(let preset) = style else { return }
    custom = preset.theme
    style = .custom
  }

  private enum CodingKeys: String, CodingKey {
    case style, custom
  }

  private static let customKey = "custom"

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let raw = (try? c.decodeIfPresent(String.self, forKey: .style)) ?? nil
    if raw == Self.customKey {
      style = .custom
    } else if let raw, let preset = CutinPreset(rawValue: raw) {
      style = .preset(preset)
    }
    custom = (try? c.decodeIfPresent(CutinTheme.self, forKey: .custom)) ?? custom
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch style {
    case .preset(let preset): try c.encode(preset.rawValue, forKey: .style)
    case .custom: try c.encode(Self.customKey, forKey: .style)
    }
    try c.encode(custom, forKey: .custom)
  }
}
