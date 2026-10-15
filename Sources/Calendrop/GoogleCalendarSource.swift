import CalendropCore
import Foundation

enum CalendarError: LocalizedError {
  case needsSignIn
  case http(Int, String)

  var errorDescription: String? {
    switch self {
    case .needsSignIn: "Sign-in required."
    case .http(let code, let body): "Google Calendar API returned \(code): \(body.prefix(200))"
    }
  }
}

/// Real accounts: signs in through the browser, keeps each refresh token in this
/// Mac's Keychain and reads the Google Calendar API.
@MainActor
final class GoogleCalendarSource: CalendarSource {
  private struct AccessToken {
    var value: String
    var expiry: Date
  }

  private let client: OAuthClient
  private var accessTokens: [String: AccessToken] = [:]
  private let api = URL(string: "https://www.googleapis.com/calendar/v3")!

  init(client: OAuthClient) {
    self.client = client
  }

  let notice: String? = nil
  let presetAccounts: [(email: String, label: String?)] = []

  func isSignedIn(_ account: String) -> Bool {
    Keychain.refreshToken(for: account) != nil
  }

  func signIn(hint: String?, existing: [String]) async throws -> String {
    let (email, refreshToken) = try await LoopbackAuthenticator.authorize(client: client, loginHint: hint)
    try Keychain.setRefreshToken(refreshToken, for: email)
    accessTokens[email] = nil
    return email
  }

  func forget(_ account: String) {
    Keychain.deleteRefreshToken(for: account)
    accessTokens[account] = nil
  }

  /// Every calendar the account can read, marked with Google Calendar's own selection.
  func calendars(account: String) async throws -> [CalendarRef] {
    let token = try await accessToken(for: account)
    var calendars: [CalendarRef] = []
    var pageToken: String?
    repeat {
      var query = [("minAccessRole", "reader")]
      if let pageToken { query.append(("pageToken", pageToken)) }
      let data = try await get(
        api.appendingPathComponent("users/me/calendarList"), query: query, token: token, account: account)
      calendars += try GoogleCalendarParser.calendars(fromCalendarList: data)
      pageToken = try GoogleCalendarParser.nextPageToken(from: data)
    } while pageToken != nil
    return calendars
  }

  /// Every meeting between `from` and `to` on `calendars`.
  func meetings(account: String, calendars: [CalendarRef], from: Date, to: Date)
    async throws -> [Meeting]
  {
    let token = try await accessToken(for: account)
    let iso = ISO8601DateFormatter()
    var lists: [[Meeting]] = []
    for calendar in calendars {
      var pageToken: String?
      repeat {
        var query = [
          ("timeMin", iso.string(from: from)),
          ("timeMax", iso.string(from: to)),
          ("singleEvents", "true"),
          ("orderBy", "startTime"),
          ("maxResults", "250"),
        ]
        if let pageToken { query.append(("pageToken", pageToken)) }
        // The calendar ID is one path segment and contains "@" and "#".
        let url = URL(string: "\(api.absoluteString)/calendars/\(calendar.id.urlPathSegmentEscaped)/events")!
        let data = try await get(url, query: query, token: token, account: account)
        lists.append(try GoogleCalendarParser.meetings(fromEvents: data, account: account, calendar: calendar))
        pageToken = try GoogleCalendarParser.nextPageToken(from: data)
      } while pageToken != nil
    }
    return Meeting.merge(lists)
  }

  private func accessToken(for account: String) async throws -> String {
    if let cached = accessTokens[account], cached.expiry > Date().addingTimeInterval(60) {
      return cached.value
    }
    guard let refreshToken = Keychain.refreshToken(for: account) else { throw CalendarError.needsSignIn }

    var request = URLRequest(url: OAuthClient.tokenEndpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = client.refreshBody(refreshToken: refreshToken)
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
      if let error = try? JSONDecoder().decode(TokenErrorResponse.self, from: data), error.requiresSignIn {
        Keychain.deleteRefreshToken(for: account)
        throw CalendarError.needsSignIn
      }
      throw CalendarError.http(status, String(decoding: data, as: UTF8.self))
    }
    let token = try JSONDecoder().decode(TokenResponse.self, from: data)
    accessTokens[account] = AccessToken(value: token.accessToken, expiry: Date().addingTimeInterval(token.expiresIn))
    return token.accessToken
  }

  private func get(_ url: URL, query: [(String, String)], token: String, account: String) async throws -> Data {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    if status == 401 { accessTokens[account] = nil }
    guard status == 200 else { throw CalendarError.http(status, String(decoding: data, as: UTF8.self)) }
    return data
  }
}
