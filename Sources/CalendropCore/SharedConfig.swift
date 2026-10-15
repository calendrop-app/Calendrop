import Foundation

/// Settings shared between the user's Macs through iCloud Drive.
///
/// Deliberately holds no tokens and no OAuth client: the client ships inside the
/// app, and each Mac keeps its own refresh tokens in its local Keychain. An account
/// listed here without a local token is shown as "sign in required", and signing in
/// sends its address to Google as `login_hint`.
public struct SharedConfig: Codable, Equatable, Sendable {
  public var accounts: [String] = []
  public var leadMinutes: Int = 2
  public var cutInWithoutJoinLink = false
  public var appearance = CutinAppearance()

  public init() {}

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = SharedConfig()
    accounts = try c.decodeIfPresent([String].self, forKey: .accounts) ?? defaults.accounts
    leadMinutes = try c.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? defaults.leadMinutes
    cutInWithoutJoinLink =
      try c.decodeIfPresent(Bool.self, forKey: .cutInWithoutJoinLink) ?? defaults.cutInWithoutJoinLink
    appearance = (try? c.decodeIfPresent(CutinAppearance.self, forKey: .appearance)) ?? defaults.appearance
  }

  public mutating func addAccount(_ email: String) {
    let normalized = email.lowercased()
    if !accounts.contains(normalized) { accounts.append(normalized) }
  }

  public mutating func removeAccount(_ email: String) {
    accounts.removeAll { $0 == email.lowercased() }
  }
}

public struct ConfigStore: Sendable {
  public var url: URL

  public init(url: URL) {
    self.url = url
  }

  /// iCloud Drive when it is enabled on this Mac, otherwise a machine-local folder.
  public static func defaultURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: cloudDocs.path, isDirectory: &isDirectory), isDirectory.boolValue {
      return cloudDocs.appendingPathComponent("Calendrop/config.json")
    }
    return home.appendingPathComponent("Library/Application Support/Calendrop/config.json")
  }

  /// A missing or unreadable file yields the defaults rather than an error, so a
  /// half-synced iCloud file never stops the app from starting.
  public func load() -> SharedConfig {
    guard let data = try? Data(contentsOf: url) else { return SharedConfig() }
    return (try? JSONDecoder().decode(SharedConfig.self, from: data)) ?? SharedConfig()
  }

  public func save(_ config: SharedConfig) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(config).write(to: url, options: .atomic)
  }
}
