import Foundation

/// Where the refresh tokens are kept: one item holding every account's token, and
/// the per-account items older versions wrote.
public protocol RefreshTokenStorage: AnyObject {
  /// The item's content, or nil when there is no item yet.
  func read() throws -> Data?
  func write(_ data: Data) throws
  /// The accounts that still have an item of their own.
  func legacyAccounts() throws -> [String]
  func readLegacy(_ account: String) throws -> String?
  func deleteLegacy(_ account: String) throws
}

public enum RefreshTokenStorageError: LocalizedError {
  /// The user turned down macOS's question whether Calendrop may read the item.
  case refused

  public var errorDescription: String? {
    "Calendrop was not allowed to read its sign-in from the Keychain."
  }
}

/// Every account's refresh token, read from storage once and kept in memory.
///
/// macOS asks the user before an app outside an item's access list reads it, once
/// per item. Keeping every token in one item and reading it once means one question
/// however many accounts are signed in.
public final class RefreshTokenVault {
  private let storage: any RefreshTokenStorage
  /// Nil until storage has been read. A failed read leaves it nil, so a later write
  /// cannot replace tokens it never saw.
  private var tokens: [String: String]?
  /// Whether the user turned the read down. Reads that come on their own, such as
  /// the periodic refresh, then give up instead of asking again; a sign-in asks again.
  private var refused = false

  public init(storage: any RefreshTokenStorage) {
    self.storage = storage
  }

  public func token(for account: String) throws -> String? {
    try loaded(retrying: false)[account.lowercased()]
  }

  public func set(_ token: String, for account: String) throws {
    var next = try loaded(retrying: true)
    next[account.lowercased()] = token
    try save(next)
  }

  public func remove(_ account: String) throws {
    // A per-account item left behind by a refused move goes too, or a later launch
    // would bring it back.
    try storage.deleteLegacy(account.lowercased())
    var next = try loaded(retrying: true)
    guard next.removeValue(forKey: account.lowercased()) != nil else { return }
    try save(next)
  }

  private func save(_ next: [String: String]) throws {
    try storage.write(try JSONEncoder().encode(next))
    tokens = next
  }

  private func loaded(retrying: Bool) throws -> [String: String] {
    if let tokens { return tokens }
    if !retrying, refused { throw RefreshTokenStorageError.refused }
    let data: Data?
    do {
      data = try storage.read()
      refused = false
    } catch RefreshTokenStorageError.refused {
      // Any other failure, such as a keychain locked during sleep, is tried again.
      refused = true
      throw RefreshTokenStorageError.refused
    }
    // Content that does not decode holds no token anyone can use.
    var stored = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    // A per-account item that cannot be read now stays, to be moved on a later launch.
    var moved: [String] = []
    for account in try storage.legacyAccounts() {
      // An account the item already holds is not read again: each read may ask the user.
      if stored[account.lowercased()] == nil {
        // After one refusal the rest would only ask again.
        guard let token = try? storage.readLegacy(account) else { break }
        stored[account.lowercased()] = token
      }
      moved.append(account)
    }
    tokens = stored
    // A move that cannot be written keeps the per-account items for a later launch;
    // what was read still serves this one, so it is not read again.
    if !moved.isEmpty, (try? save(stored)) != nil {
      for account in moved { try? storage.deleteLegacy(account) }
    }
    return stored
  }
}
