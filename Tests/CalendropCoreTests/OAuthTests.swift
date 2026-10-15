import Foundation
import Testing

@testable import CalendropCore

@Suite struct OAuthTests {
  let client = OAuthClient(id: "cid.apps.googleusercontent.com", secret: "sec")

  @Test func readsTheClientEmbeddedInTheBundle() {
    let info: [String: Any] = [
      "CalendropGoogleClientID": " cid.apps.googleusercontent.com\n", "CalendropGoogleClientSecret": "sec",
    ]
    #expect(OAuthClient(infoDictionary: info) == OAuthClient(id: "cid.apps.googleusercontent.com", secret: "sec"))
  }

  @Test(
    arguments: [
      [:],
      ["CalendropGoogleClientID": ""],
      ["CalendropGoogleClientID": "   "],
      ["CalendropGoogleClientID": "cid"],
      ["CalendropGoogleClientID": "cid", "CalendropGoogleClientSecret": " \n"],
      ["CalendropGoogleClientSecret": "sec"],
    ] as [[String: String]])
  func reportsABuildWithoutAClient(info: [String: String]) {
    #expect(OAuthClient(infoDictionary: info) == nil)
  }

  @Test(arguments: [
    ("invalid_grant", true),
    ("unauthorized_client", false),
    ("invalid_client", false),
    ("invalid_request", false),
  ])
  func tellsWhichTokenErrorsNeedTheUserToSignInAgain(code: String, expected: Bool) throws {
    let response = try JSONDecoder().decode(TokenErrorResponse.self, from: Data(#"{"error":"\#(code)"}"#.utf8))
    #expect(response.requiresSignIn == expected)
  }

  @Test func pkceChallengeMatchesRFC7636Example() {
    // Appendix B of RFC 7636.
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test func pkceVerifierIsURLSafeAndLongEnough() {
    let v = PKCE.makeVerifier()
    #expect(v.count >= 43 && v.count <= 128)
    #expect(v.allSatisfy { $0.isLetter || $0.isNumber || "-._~".contains($0) })
  }

  @Test func authorizationURLCarriesLoginHint() throws {
    let url = client.authorizationURL(
      redirectURI: "http://127.0.0.1:5000", codeChallenge: "chal", state: "st", loginHint: "me+x@example.com")
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let q = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    #expect(url.host == "accounts.google.com")
    #expect(q["client_id"] == "cid.apps.googleusercontent.com")
    #expect(q["redirect_uri"] == "http://127.0.0.1:5000")
    #expect(q["response_type"] == "code")
    #expect(q["code_challenge"] == "chal")
    #expect(q["code_challenge_method"] == "S256")
    #expect(q["state"] == "st")
    #expect(q["access_type"] == "offline")
    #expect(q["login_hint"] == "me+x@example.com")
    #expect(q["scope"]?.split(separator: " ").contains("https://www.googleapis.com/auth/calendar.readonly") == true)
    #expect(q["scope"]?.split(separator: " ").contains("email") == true)
  }

  @Test func authorizationURLOmitsLoginHintWhenAbsent() {
    let url = client.authorizationURL(redirectURI: "http://127.0.0.1:1", codeChallenge: "c", state: "s", loginHint: nil)
    #expect(!url.absoluteString.contains("login_hint"))
  }

  @Test func formBodiesAreURLEncoded() {
    let body = String(
      decoding: client.codeExchangeBody(code: "4/a+b", verifier: "v", redirectURI: "http://127.0.0.1:1"), as: UTF8.self)
    let pairs = Set(body.split(separator: "&").map(String.init))
    #expect(pairs.contains("code=4%2Fa%2Bb"))
    #expect(pairs.contains("grant_type=authorization_code"))
    #expect(pairs.contains("code_verifier=v"))
    #expect(pairs.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A1"))
    #expect(pairs.contains("client_secret=sec"))

    let refresh = String(decoding: client.refreshBody(refreshToken: "1//r"), as: UTF8.self)
    #expect(
      Set(refresh.split(separator: "&").map(String.init)).isSuperset(of: [
        "grant_type=refresh_token", "refresh_token=1%2F%2Fr",
      ]))
  }

  @Test func decodesEmailFromIDToken() throws {
    // Header and signature are irrelevant: the token arrives over TLS straight from Google.
    let payload = Data(#"{"email":"me@example.com","sub":"1"}"#.utf8).base64EncodedString()
      .replacingOccurrences(of: "=", with: "")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
    let token = "eyJhbGciOiJSUzI1NiJ9.\(payload).sig"
    #expect(IDToken.email(from: token) == "me@example.com")
    #expect(IDToken.email(from: "garbage") == nil)
  }

  @Test func parsesRedirectRequestLine() {
    let ok = LoopbackRequest.parse("GET /?state=st&code=4%2Fabc&scope=x HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
    #expect(ok == .code("4/abc", state: "st"))
    #expect(LoopbackRequest.parse("GET /?error=access_denied&state=st HTTP/1.1\r\n") == .error("access_denied"))
    #expect(LoopbackRequest.parse("GET /favicon.ico HTTP/1.1\r\n") == .unrelated)
    #expect(LoopbackRequest.parse("") == .unrelated)
  }
}
