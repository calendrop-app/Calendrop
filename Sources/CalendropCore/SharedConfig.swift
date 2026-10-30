import Foundation

/// Settings shared between the user's Macs through iCloud Drive.
///
/// Deliberately holds no tokens and no OAuth client: the client ships inside the
/// app, and each Mac keeps its own refresh tokens in its local Keychain. An account
/// listed here without a local token is shown as "sign in required", and signing in
/// sends its address to Google as `login_hint`.
public struct SharedConfig: Codable, Equatable, Sendable {
  public var accounts: [AccountSettings] = []
  public private(set) var leadMinutes: Int = 2
  /// Beyond two hours a cut-in would interrupt long before it is useful.
  public static let leadMinutesRange = 0...120
  public var cutInWithoutJoinLink = false
  public var cutInWithoutAcceptance = true
  public var cutInDuringCall = CutinPresentation.compact
  public var coverAfterCall = true
  public var appearance = CutinAppearance()
  public var showMeetingTitleInMenuBar = true

  private enum CodingKeys: String, CodingKey {
    case accounts, leadMinutes, cutInWithoutJoinLink, cutInWithoutAcceptance, cutInDuringCall, coverAfterCall,
      appearance, showMeetingTitleInMenuBar
  }

  public var callAwareness: CallAwareness {
    CallAwareness(duringCall: cutInDuringCall, coverAfterCall: coverAfterCall)
  }

  public init() {}

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = SharedConfig()
    accounts = (try? Self.decodeAccounts(from: c)) ?? defaults.accounts
    setLeadMinutes(try c.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? defaults.leadMinutes)
    cutInWithoutJoinLink =
      try c.decodeIfPresent(Bool.self, forKey: .cutInWithoutJoinLink) ?? defaults.cutInWithoutJoinLink
    cutInWithoutAcceptance =
      try c.decodeIfPresent(Bool.self, forKey: .cutInWithoutAcceptance) ?? defaults.cutInWithoutAcceptance
    cutInDuringCall =
      (try? c.decodeIfPresent(CutinPresentation.self, forKey: .cutInDuringCall)) ?? defaults.cutInDuringCall
    coverAfterCall = try c.decodeIfPresent(Bool.self, forKey: .coverAfterCall) ?? defaults.coverAfterCall
    appearance = (try? c.decodeIfPresent(CutinAppearance.self, forKey: .appearance)) ?? defaults.appearance
    showMeetingTitleInMenuBar =
      try c.decodeIfPresent(Bool.self, forKey: .showMeetingTitleInMenuBar) ?? defaults.showMeetingTitleInMenuBar
  }

  /// Skips an entry it cannot read rather than losing every account to one hand-edit
  /// gone wrong.
  private static func decodeAccounts(from c: KeyedDecodingContainer<CodingKeys>) throws -> [AccountSettings] {
    guard c.contains(.accounts) else { return [] }
    var list = try c.nestedUnkeyedContainer(forKey: .accounts)
    var accounts: [AccountSettings] = []
    while !list.isAtEnd {
      let stored: StoredAccount?
      if let entry = try? list.decode(StoredAccount.self) {
        stored = entry
      } else {
        _ = try? list.decode(Skipped.self)
        stored = nil
      }
      guard let stored, !accounts.contains(where: { $0.email == stored.email.lowercased() }) else { continue }
      accounts.append(
        AccountSettings(
          email: stored.email,
          label: stored.label,
          color: stored.color.flatMap(ThemeColor.init(hex:)) ?? AccountPalette.color(after: accounts.map(\.color)),
          calendarIDs: stored.calendarIDs))
    }
    return accounts
  }

  private struct StoredAccount: Decodable {
    var email: String
    var label: String?
    var color: String?
    var calendarIDs: [String]?

    init(email: String) { self.email = email }
  }

  private struct Skipped: Decodable {
    init(from decoder: Decoder) throws {}
  }

  public mutating func setLeadMinutes(_ minutes: Int) {
    leadMinutes = min(max(minutes, Self.leadMinutesRange.lowerBound), Self.leadMinutesRange.upperBound)
  }

  public func account(_ email: String) -> AccountSettings? {
    accounts.first { $0.email == email.lowercased() }
  }

  /// Adds the account with the first unused colour; an account already present keeps its settings.
  public mutating func addAccount(_ email: String) {
    guard account(email) == nil else { return }
    accounts.append(AccountSettings(email: email, color: AccountPalette.color(after: accounts.map(\.color))))
  }

  public mutating func updateAccount(_ email: String, _ change: (inout AccountSettings) -> Void) {
    guard let index = accounts.firstIndex(where: { $0.email == email.lowercased() }) else { return }
    change(&accounts[index])
  }

  public mutating func removeAccount(_ email: String) {
    accounts.removeAll { $0.email == email.lowercased() }
  }
}

/// Where the app keeps `SharedConfig`.
public protocol ConfigStorage {
  /// The file holding the settings, or nil when they are not kept anywhere.
  var location: URL? { get }
  func load() -> SharedConfig
  func save(_ config: SharedConfig) throws
}

/// Settings for nothing worth keeping, such as sample accounts: they last as long
/// as the store and never touch the disk.
public final class MemoryConfigStore: ConfigStorage {
  private var config = SharedConfig()

  public init() {}

  public var location: URL? { nil }

  public func load() -> SharedConfig { config }

  public func save(_ config: SharedConfig) throws {
    self.config = config
  }
}

public struct ConfigStore: ConfigStorage, Sendable {
  public var url: URL

  public init(url: URL) {
    self.url = url
  }

  public var location: URL? { url }

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
