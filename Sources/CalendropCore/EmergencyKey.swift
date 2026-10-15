/// The keyboard way out of a cut-in, for when its on-screen controls cannot be
/// reached. Four keys at once, so it never fires by accident the way a lone
/// Escape would.
public enum EmergencyKey {
  /// Modifier keys, mirroring AppKit's so the core stays free of it.
  public struct Modifiers: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let capsLock = Modifiers(rawValue: 1 << 16)
    public static let shift = Modifiers(rawValue: 1 << 17)
    public static let control = Modifiers(rawValue: 1 << 18)
    public static let option = Modifiers(rawValue: 1 << 19)
    public static let command = Modifiers(rawValue: 1 << 20)
    public static let function = Modifiers(rawValue: 1 << 23)
  }

  /// The virtual key code of Escape.
  public static let keyCode: UInt16 = 53
  public static let modifiers: Modifiers = [.control, .option, .command]
  public static let symbol = "⌃⌥⌘⎋"

  /// Caps Lock and the function key are ignored; any other extra modifier means
  /// the user meant something else.
  public static func matches(keyCode: UInt16, modifiers: Modifiers) -> Bool {
    let relevant = modifiers.intersection([.shift, .control, .option, .command])
    return keyCode == Self.keyCode && relevant == Self.modifiers
  }
}
