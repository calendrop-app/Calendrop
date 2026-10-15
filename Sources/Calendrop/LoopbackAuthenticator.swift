import AppKit
import CalendropCore
import Foundation
import Network

enum AuthError: LocalizedError {
  case denied(String)
  case timedOut
  case noRefreshToken
  case calendarAccessNotGranted
  case tokenEndpoint(String)

  var errorDescription: String? {
    switch self {
    case .denied(let reason): "Google sign-in was cancelled (\(reason))."
    case .timedOut: "Google sign-in timed out."
    case .noRefreshToken: "Google did not return a refresh token."
    case .calendarAccessNotGranted:
      "Calendrop needs to see your calendars and their events. Sign in again and leave both permissions ticked."
    case .tokenEndpoint(let message): "Google token endpoint: \(message)"
    }
  }
}

/// OAuth 2.0 for installed apps: the browser redirects to a one-shot listener on
/// 127.0.0.1, and the code is exchanged with PKCE.
@MainActor
enum LoopbackAuthenticator {
  /// A grant for everything Calendrop reads, with the refresh token that keeps it.
  struct Grant {
    var accessToken: String
    var expiresIn: Double
    var refreshToken: String
  }

  static func authorize(client: OAuthClient, loginHint: String?) async throws -> Grant {
    let server = try LoopbackServer()
    let port = try await server.start()
    defer { server.stop() }

    let redirectURI = "http://127.0.0.1:\(port)"
    let verifier = PKCE.makeVerifier()
    let state = UUID().uuidString
    NSWorkspace.shared.open(
      client.authorizationURL(
        redirectURI: redirectURI, codeChallenge: PKCE.challenge(for: verifier), state: state, loginHint: loginHint))

    let timeout = Task {
      try await Task.sleep(for: .seconds(300))
      server.stop()
    }
    defer { timeout.cancel() }

    for await request in server.requests {
      switch request {
      case .error(let reason):
        throw AuthError.denied(reason)
      case .code(let code, let returnedState) where returnedState == state:
        return try await exchange(client: client, code: code, verifier: verifier, redirectURI: redirectURI)
      default:
        continue
      }
    }
    // The stream also ends when the waiting task is cancelled.
    try Task.checkCancellation()
    throw AuthError.timedOut
  }

  private static func exchange(client: OAuthClient, code: String, verifier: String, redirectURI: String)
    async throws -> Grant
  {
    var request = URLRequest(url: OAuthClient.tokenEndpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = client.codeExchangeBody(code: code, verifier: verifier, redirectURI: redirectURI)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw AuthError.tokenEndpoint(String(decoding: data, as: UTF8.self))
    }
    let token = try JSONDecoder().decode(TokenResponse.self, from: data)
    guard let refreshToken = token.refreshToken else { throw AuthError.noRefreshToken }
    guard OAuthClient.grantsEverythingNeeded(token.scope ?? "") else { throw AuthError.calendarAccessNotGranted }
    return Grant(accessToken: token.accessToken, expiresIn: token.expiresIn, refreshToken: refreshToken)
  }
}

@MainActor
private final class LoopbackServer {
  private let listener: NWListener
  private let continuation: AsyncStream<LoopbackRequest>.Continuation
  private var startResumed = false
  let requests: AsyncStream<LoopbackRequest>

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
    (requests, continuation) = AsyncStream.makeStream()
  }

  func start() async throws -> UInt16 {
    try await withCheckedThrowingContinuation { (ready: CheckedContinuation<UInt16, Error>) in
      listener.stateUpdateHandler = { [weak self, listener] state in
        MainActor.assumeIsolated {
          guard let self, !self.startResumed else { return }
          switch state {
          case .ready:
            self.startResumed = true
            ready.resume(returning: listener.port?.rawValue ?? 0)
          case .failed(let error):
            self.startResumed = true
            ready.resume(throwing: error)
          default:
            break
          }
        }
      }
      listener.newConnectionHandler = { [weak self] connection in
        MainActor.assumeIsolated { self?.handle(connection) }
      }
      listener.start(queue: .main)
    }
  }

  func stop() {
    listener.cancel()
    continuation.finish()
  }

  private static let maxRequestSize = 64 * 1024

  private func handle(_ connection: NWConnection) {
    connection.start(queue: .main)
    receiveRequestLine(on: connection, buffered: Data())
  }

  /// TCP may deliver the request in pieces; parse only once the request line is complete.
  private func receiveRequestLine(on connection: NWConnection, buffered: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestSize) {
      [weak self] data, _, isComplete, error in
      MainActor.assumeIsolated {
        var buffer = buffered
        if let data { buffer.append(data) }
        let lineEnded = buffer.range(of: Data("\r\n".utf8)) != nil
        if !lineEnded, !isComplete, error == nil, buffer.count < Self.maxRequestSize {
          self?.receiveRequestLine(on: connection, buffered: buffer)
        } else {
          self?.respond(on: connection, to: LoopbackRequest.parse(String(decoding: buffer, as: UTF8.self)))
        }
      }
    }
  }

  private func respond(on connection: NWConnection, to request: LoopbackRequest) {
    let (status, message): (String, String) =
      switch request {
      case .code: ("200 OK", "Signed in. You can close this tab and return to Calendrop.")
      case .error: ("200 OK", "Sign-in was cancelled. You can close this tab.")
      case .unrelated: ("404 Not Found", "Not found.")
      }
    let html =
      "<!doctype html><meta charset=utf-8><title>Calendrop</title>"
      + "<body style=\"font:16px -apple-system,sans-serif;padding:4em;text-align:center\"><h2>\(message)</h2>"
    let response =
      "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
      + "Content-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    if request != .unrelated {
      continuation.yield(request)
    }
  }
}
