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

@MainActor
final class GoogleCalendarService {
  private struct AccessToken {
    var value: String
    var expiry: Date
  }

  private var accessTokens: [String: AccessToken] = [:]
  private let api = URL(string: "https://www.googleapis.com/calendar/v3")!

  func forget(account: String) {
    accessTokens[account] = nil
  }

  /// Every meeting between `from` and `to` on the calendars the account has selected.
  func meetings(account: String, client: OAuthClient, from: Date, to: Date) async throws -> [Meeting] {
    let token = try await accessToken(for: account, client: client)
    var calendars: [CalendarRef] = []
    var calendarPageToken: String?
    repeat {
      var query = [("minAccessRole", "reader")]
      if let calendarPageToken { query.append(("pageToken", calendarPageToken)) }
      let data = try await get(
        api.appendingPathComponent("users/me/calendarList"), query: query, token: token, account: account)
      calendars += try GoogleCalendarParser.calendars(fromCalendarList: data)
      calendarPageToken = try GoogleCalendarParser.nextPageToken(from: data)
    } while calendarPageToken != nil

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
        lists.append(try GoogleCalendarParser.meetings(fromEvents: data, account: account, calendarName: calendar.name))
        pageToken = try GoogleCalendarParser.nextPageToken(from: data)
      } while pageToken != nil
    }
    return Meeting.merge(lists)
  }

  private func accessToken(for account: String, client: OAuthClient) async throws -> String {
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
      // A revoked or expired grant cannot recover without the user.
      if let error = try? JSONDecoder().decode(TokenErrorResponse.self, from: data), error.error == "invalid_grant" {
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
