import CalendropCore
import Foundation
import Security

/// Refresh tokens in this Mac's login Keychain, in one item holding every account's
/// token.
///
/// The item is explicitly non-synchronizable: tokens never leave the machine, and a
/// second Mac signs in on its own.
final class KeychainStorage: RefreshTokenStorage {
  private static let service = "io.github.calendrop-app.calendrop.refresh-tokens"
  private static let itemAccount = "accounts"

  private static let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: itemAccount,
    kSecAttrSynchronizable as String: false,
  ]

  func read() throws -> Data? {
    var q = Self.query
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    if status == errSecAuthFailed || status == errSecUserCanceled { throw RefreshTokenStorageError.refused }
    guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
    return data
  }

  func write(_ data: Data) throws {
    let q = Self.query
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
}

struct KeychainError: LocalizedError {
  var status: OSStatus
  var errorDescription: String? {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? String(status)
    return String(localized: "Keychain error: \(message)")
  }
}
