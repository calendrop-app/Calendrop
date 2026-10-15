import Foundation
import Security

/// Refresh tokens, one per Google account, in this Mac's login Keychain.
///
/// Items are explicitly non-synchronizable: tokens never leave the machine, and a
/// second Mac signs in on its own.
enum Keychain {
  private static let service = "com.lambdalisue.calendrop.refresh-token"

  private static func query(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account.lowercased(),
      kSecAttrSynchronizable as String: false,
    ]
  }

  static func refreshToken(for account: String) -> String? {
    var q = query(account: account)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  static func setRefreshToken(_ token: String, for account: String) throws {
    let data = Data(token.utf8)
    let status = SecItemUpdate(query(account: account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var q = query(account: account)
      q[kSecValueData as String] = data
      q[kSecAttrLabel as String] = "Calendrop (\(account))"
      q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let added = SecItemAdd(q as CFDictionary, nil)
      guard added == errSecSuccess else { throw KeychainError(status: added) }
    } else if status != errSecSuccess {
      throw KeychainError(status: status)
    }
  }

  static func deleteRefreshToken(for account: String) {
    SecItemDelete(query(account: account) as CFDictionary)
  }
}

struct KeychainError: LocalizedError {
  var status: OSStatus
  var errorDescription: String? {
    "Keychain error: \(SecCopyErrorMessageString(status, nil) as String? ?? String(status))"
  }
}
