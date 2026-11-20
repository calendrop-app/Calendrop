import Foundation

/// The sound a cut-in makes when a meeting comes due, or silence.
///
/// Stored by the name of a macOS system sound rather than as a closed list, so a
/// sound one Mac offers survives a trip through the shared settings on a Mac that
/// does not; a Mac that lacks it simply plays nothing.
public struct CutinSound: Hashable, Codable, Sendable {
  /// The system sound's name, nil for silence.
  public let systemName: String?

  public static let none = CutinSound(nil)

  public init(systemName: String) {
    self.init(Optional(systemName))
  }

  private init(_ systemName: String?) {
    self.systemName = systemName
  }

  /// Silence first, then the sounds every supported macOS ships in
  /// /System/Library/Sounds.
  public static let choices: [CutinSound] =
    [.none]
    + [
      "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
      "Submarine", "Tink",
    ].map(CutinSound.init(systemName:))

  /// Sounds only when a meeting newly comes due and the cut-in is on screen: one held
  /// back during a call was chosen not to interrupt it.
  public func plays(arriving: Bool, as presentation: CutinPresentation) -> Bool {
    systemName != nil && arriving && presentation != .hidden
  }

  public init(from decoder: Decoder) throws {
    let name = try decoder.singleValueContainer().decode(String.self)
    self.init(name.isEmpty ? nil : name)
  }

  /// Silence is written as an empty name.
  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(systemName ?? "")
  }
}
