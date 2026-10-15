import CalendropCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
  enum AccountState: Equatable {
    case ok
    case needsSignIn
    case error(String)
  }

  @Published private(set) var config: SharedConfig
  @Published private(set) var meetings: [Meeting] = []
  @Published private(set) var accountStates: [String: AccountState] = [:]
  @Published private(set) var isSigningIn = false
  @Published var lastError: String?

  let store: ConfigStore
  /// Demo mode runs on `DemoCalendar` and never reads or writes Google, the shared
  /// config file, the Keychain or the persisted acknowledgements.
  let isDemo: Bool
  /// Embedded by `just bundle`; nil in a build made without the maintainer's client.
  let oauthClient = OAuthClient(infoDictionary: Bundle.main.infoDictionary ?? [:])
  static let missingClientMessage =
    "This build of Calendrop has no Google sign-in. Build it with the OAuth client as the README describes."
  private let service = GoogleCalendarService()
  private var isRefreshing = false
  private var demoAcknowledged: Set<String> = []
  private static let acknowledgedKey = "acknowledgedMeetings"

  init(isDemo: Bool = false, store: ConfigStore = ConfigStore(url: ConfigStore.defaultURL())) {
    self.isDemo = isDemo
    self.store = store
    if isDemo {
      var demo = SharedConfig()
      demo.accounts = DemoCalendar.accounts
      self.config = demo
    } else {
      self.config = store.load()
    }
  }

  var policy: CutinPolicy { CutinPolicy(leadTime: TimeInterval(max(0, config.leadMinutes) * 60)) }

  var needsAttention: Bool {
    if isDemo { return false }
    return oauthClient == nil || config.accounts.isEmpty || accountStates.values.contains { $0 != .ok }
  }

  func state(of account: String) -> AccountState {
    if isDemo { return .ok }
    return accountStates[account] ?? (Keychain.refreshToken(for: account) == nil ? .needsSignIn : .ok)
  }

  // MARK: Shared config

  func updateConfig(_ mutate: (inout SharedConfig) -> Void) {
    var next = config
    mutate(&next)
    guard next != config else { return }
    config = next
    if isDemo { return }
    do {
      try store.save(next)
    } catch {
      lastError = "Could not save \(store.url.path): \(error.localizedDescription)"
    }
  }

  /// Picks up edits another Mac made through iCloud Drive.
  private func reloadConfigFromDisk() {
    let onDisk = store.load()
    if onDisk != config { config = onDisk }
  }

  // MARK: Accounts

  func signIn(hint: String?) async {
    if isDemo {
      lastError = "Sign-in is disabled in demo mode."
      return
    }
    // Settings already shows `missingClientMessage` whenever the client is absent.
    guard let client = oauthClient else { return }
    isSigningIn = true
    defer { isSigningIn = false }
    do {
      let (email, refreshToken) = try await LoopbackAuthenticator.authorize(client: client, loginHint: hint)
      try Keychain.setRefreshToken(refreshToken, for: email)
      service.forget(account: email)
      updateConfig { $0.addAccount(email) }
      accountStates[email] = .ok
      lastError = nil
      await refresh()
    } catch {
      lastError = error.localizedDescription
    }
  }

  /// Removes the account from every Mac (through the shared config) and drops this Mac's token.
  func remove(account: String) {
    if !isDemo {
      Keychain.deleteRefreshToken(for: account)
      service.forget(account: account)
    }
    accountStates[account] = nil
    updateConfig { $0.removeAccount(account) }
    meetings.removeAll { $0.account == account }
  }

  // MARK: Meetings

  func refresh() async {
    if isDemo {
      // The periodic refresh must not shift the schedule the user is watching.
      if meetings.isEmpty { meetings = DemoCalendar.meetings(now: Date()) }
      return
    }
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    reloadConfigFromDisk()
    guard let client = oauthClient else {
      meetings = []
      return
    }
    let calendar = Calendar.current
    let from = calendar.startOfDay(for: Date())
    let to = calendar.date(byAdding: .day, value: 2, to: from)!

    var lists: [[Meeting]] = []
    var states: [String: AccountState] = [:]
    for account in config.accounts {
      do {
        lists.append(try await service.meetings(account: account, client: client, from: from, to: to))
        states[account] = .ok
      } catch CalendarError.needsSignIn {
        states[account] = .needsSignIn
      } catch {
        // Keep what we already know so cut-ins still fire while offline.
        lists.append(meetings.filter { $0.account == account })
        states[account] = .error(error.localizedDescription)
      }
    }
    // An account removed while its fetch was in flight must not come back.
    let current = Set(config.accounts)
    meetings = Meeting.merge(lists.map { $0.filter { current.contains($0.account) } })
    accountStates = states.filter { current.contains($0.key) }
  }

  /// Replaces any earlier scenario with `scenario`, due at once.
  func tryDemo(_ scenario: DemoCalendar.Scenario) {
    guard isDemo else { return }
    meetings = Meeting.merge([
      meetings.filter { !DemoCalendar.isScenario($0) },
      scenario.meetings(now: Date(), leadTime: policy.leadTime),
    ])
  }

  /// The meetings allowed to cut in. In demo mode only scenarios the user asked for do.
  var cutInCandidates: [Meeting] {
    isDemo ? meetings.filter(DemoCalendar.isScenario) : meetings
  }

  // MARK: Acknowledgements

  /// Meeting occurrences the user has joined or dismissed, persisted so a relaunch
  /// does not interrupt again.
  var acknowledged: Set<String> {
    if isDemo { return demoAcknowledged }
    return Set((UserDefaults.standard.dictionary(forKey: Self.acknowledgedKey) ?? [:]).keys)
  }

  func acknowledge(_ meetings: [Meeting]) {
    if isDemo {
      demoAcknowledged.formUnion(meetings.map(\.acknowledgementKey))
      return
    }
    var stored = UserDefaults.standard.dictionary(forKey: Self.acknowledgedKey) as? [String: Double] ?? [:]
    for m in meetings { stored[m.acknowledgementKey] = m.start.timeIntervalSince1970 }
    let cutoff = Date().addingTimeInterval(-2 * 24 * 3600).timeIntervalSince1970
    stored = stored.filter { $0.value > cutoff }
    UserDefaults.standard.set(stored, forKey: Self.acknowledgedKey)
  }
}
