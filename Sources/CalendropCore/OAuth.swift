import CryptoKit
import Foundation

/// A Google OAuth client of the "Desktop app" type. Google documents the secret of
/// such a client as non-confidential, which is why it may live in the shared config.
public struct OAuthClient: Sendable, Equatable {
  public var id: String
  public var secret: String

  public init(id: String, secret: String) {
    self.id = id
    self.secret = secret
  }

  public static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
  public static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
  public static let scopes = ["openid", "email", "https://www.googleapis.com/auth/calendar.readonly"]

  public func authorizationURL(redirectURI: String, codeChallenge: String, state: String, loginHint: String?) -> URL {
    var components = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
    var items = [
      URLQueryItem(name: "client_id", value: id),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " ")),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "access_type", value: "offline"),
      // Google issues a refresh token only on a consent screen; each Mac needs its own.
      URLQueryItem(name: "prompt", value: "consent"),
    ]
    if let loginHint {
      items.append(URLQueryItem(name: "login_hint", value: loginHint))
    }
    components.queryItems = items
    return components.url!
  }

  public func codeExchangeBody(code: String, verifier: String, redirectURI: String) -> Data {
    FormEncoding.encode([
      ("client_id", id),
      ("client_secret", secret),
      ("code", code),
      ("code_verifier", verifier),
      ("grant_type", "authorization_code"),
      ("redirect_uri", redirectURI),
    ])
  }

  public func refreshBody(refreshToken: String) -> Data {
    FormEncoding.encode([
      ("client_id", id),
      ("client_secret", secret),
      ("grant_type", "refresh_token"),
      ("refresh_token", refreshToken),
    ])
  }
}

public struct TokenResponse: Decodable, Sendable {
  public var accessToken: String
  public var expiresIn: Double
  public var refreshToken: String?
  public var idToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
    case idToken = "id_token"
  }
}

public struct TokenErrorResponse: Decodable, Sendable {
  public var error: String
}

public enum PKCE {
  public static func makeVerifier() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
    return base64URL(Data(bytes))
  }

  public static func challenge(for verifier: String) -> String {
    base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

public enum IDToken {
  /// Reads the `email` claim without verifying the signature: the token comes
  /// straight from Google's token endpoint over TLS, never from a third party.
  public static func email(from token: String) -> String? {
    let parts = token.split(separator: ".")
    guard parts.count == 3 else { return nil }
    var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return object["email"] as? String
  }
}

/// The browser's redirect back to the loopback listener.
public enum LoopbackRequest: Equatable, Sendable {
  case code(String, state: String)
  case error(String)
  case unrelated

  public static func parse(_ raw: String) -> LoopbackRequest {
    let requestLine = raw.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
    let parts = requestLine.split(separator: " ")
    guard parts.count >= 2, parts[0] == "GET",
      let items = URLComponents(string: String(parts[1]))?.queryItems
    else { return .unrelated }
    let q = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
    if let error = q["error"] { return .error(error) }
    if let code = q["code"], let state = q["state"] { return .code(code, state: state) }
    return .unrelated
  }
}

enum FormEncoding {
  private static let allowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

  static func encode(_ pairs: [(String, String)]) -> Data {
    let body = pairs.map { key, value in
      "\(escape(key))=\(escape(value))"
    }.joined(separator: "&")
    return Data(body.utf8)
  }

  static func escape(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
  }
}

extension String {
  /// Percent-encodes everything outside RFC 3986's unreserved set, for use as one path segment.
  public var urlPathSegmentEscaped: String { FormEncoding.escape(self) }
}
