import CalendropCore
import Foundation
import Security

/// Refresh tokens in this Mac's login Keychain: one item holding every account's
/// token, plus the one-per-account items older versions wrote.
///
/// Items are explicitly non-synchronizable: tokens never leave the machine, and a
/// second Mac signs in on its own.
final class KeychainStorage: RefreshTokenStorage {
  private static let service = "com.lambdalisue.calendrop.refresh-tokens"
  private static let itemAccount = "accounts"
  private static let legacyService = "com.lambdalisue.calendrop.refresh-token"

  private static func query(service: String, account: String?) -> [String: Any] {
    var q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrSynchronizable as String: false,
    ]
    if let account { q[kSecAttrAccount as String] = account }
    return q
  }

  private static func readData(service: String, account: String) throws -> Data? {
    var q = query(service: service, account: account)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    if status == errSecAuthFailed || status == errSecUserCanceled { throw RefreshTokenStorageError.refused }
    guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
    return data
  }

  func read() throws -> Data? {
    try Self.readData(service: Self.service, account: Self.itemAccount)
  }

  func write(_ data: Data) throws {
    let q = Self.query(service: Self.service, account: Self.itemAccount)
    let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var add = q
      add[kSecValueData as String] = data
      add[kSecAttrLabel as String] = "Calendrop sign-in"
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let added = SecItemAdd(add as CFDictionary, nil)
      guard added == errSecSuccess else { throw KeychainError(status: added) }
    } else if status != errSecSuccess {
      throw KeychainError(status: status)
    }
  }

  /// Only attributes are asked for, which macOS hands out without asking the user.
  /// The file-based keychain cannot return the data of several items at once anyway.
  func legacyAccounts() throws -> [String] {
    var q = Self.query(service: Self.legacyService, account: nil)
    q[kSecReturnAttributes as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitAll
    var result: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &result)
    if status == errSecItemNotFound { return [] }
    guard status == errSecSuccess, let items = result as? [[String: Any]] else { throw KeychainError(status: status) }
    return items.compactMap { $0[kSecAttrAccount as String] as? String }
  }

  func readLegacy(_ account: String) throws -> String? {
    try Self.readData(service: Self.legacyService, account: account).map { String(decoding: $0, as: UTF8.self) }
  }

  func deleteLegacy(_ account: String) throws {
    let status = SecItemDelete(Self.query(service: Self.legacyService, account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
  }
}

struct KeychainError: LocalizedError {
  var status: OSStatus
  var errorDescription: String? {
    "Keychain error: \(SecCopyErrorMessageString(status, nil) as String? ?? String(status))"
  }
}
