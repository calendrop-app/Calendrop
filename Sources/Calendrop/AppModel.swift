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
  /// Every calendar each account can read, as last fetched; settings choose among them.
  @Published private(set) var calendars: [String: [CalendarRef]] = [:]
  @Published private(set) var accountStates: [String: AccountState] = [:]
  @Published private(set) var isSigningIn = false
  private var signInTask: Task<Void, Never>?
  @Published var lastError: String?

  let store: any ConfigStorage
  private let source: CalendarSource
  @Published private(set) var isRefreshing = false
  /// When every account was last read without an error, and how many calendars that read.
  @Published private(set) var lastReadAt: Date?
  @Published private(set) var calendarsRead = 0
  /// What lies past tomorrow, searched only when nothing is left before it.
  struct Lookahead {
    /// The first meeting found, if any.
    var next: Meeting?
    /// The last day searched.
    var lastDay: Date
  }
  @Published private(set) var lookahead: Lookahead?
  /// The meetings of the days the menu's calendar shows, read only while it shows them.
  @Published private(set) var periodRead: PeriodRead?
  @Published private(set) var isReadingPeriod = false
  private var periodTask: Task<Void, Never>?
  private var refreshAgain = false
  /// Each account's meetings as last fetched, before merging, so an offline refresh can
  /// re-apply a changed calendar choice without losing copies merged away.
  private var lastFetched: [String: [Meeting]] = [:]
  private static let acknowledgedKey = "acknowledgedMeetings"

  init(source: CalendarSource, store: any ConfigStorage) {
    self.source = source
    self.store = store
    self.config = store.load()
    if config.accounts.isEmpty {
      updateConfig { config in
        for preset in source.presetAccounts {
          config.addAccount(preset.email)
          config.updateAccount(preset.email) { $0.label = preset.label }
        }
      }
    }
  }

  var sourceNotice: String? { source.notice }

  var policy: CutinPolicy {
    CutinPolicy(
      leadTime: TimeInterval(max(0, config.leadMinutes) * 60),
      includesMeetingsWithoutJoinLink: config.cutInWithoutJoinLink,
      includesMeetingsNotAccepted: config.cutInWithoutAcceptance)
  }

  var needsAttention: Bool {
    config.accounts.isEmpty || accountStates.values.contains { $0 != .ok }
  }

  func state(of account: String) -> AccountState {
    accountStates[account] ?? (source.isSignedIn(account) ? .ok : .needsSignIn)
  }

  // MARK: Shared config

  func updateConfig(_ mutate: (inout SharedConfig) -> Void) {
    var next = config
    mutate(&next)
    guard next != config else { return }
    config = next
    do {
      try store.save(next)
    } catch {
      let target = store.location?.path ?? String(localized: "settings")
      lastError = String(localized: "Could not save \(target): \(error.localizedDescription)")
    }
  }

  /// Changes one account's settings; a change of calendars takes effect at once.
  func updateAccount(_ email: String, _ change: (inout AccountSettings) -> Void) {
    let before = config.account(email)?.calendarIDs
    updateConfig { $0.updateAccount(email, change) }
    if config.account(email)?.calendarIDs != before {
      Task { await refresh() }
    }
  }

  /// Picks up edits another Mac made through iCloud Drive.
  private func reloadConfigFromDisk() {
    let onDisk = store.load()
    if onDisk != config { config = onDisk }
  }

  // MARK: Accounts

  /// Starts a sign-in, replacing one still waiting on the browser: a sign-in
  /// abandoned there never reports back.
  func signIn(hint: String?) {
    signInTask?.cancel()
    isSigningIn = true
    signInTask = Task { await completeSignIn(hint: hint) }
  }

  func cancelSignIn() {
    signInTask?.cancel()
    signInTask = nil
    isSigningIn = false
  }

  /// A cancelled sign-in has been replaced or given up, so it leaves the state alone.
  private func completeSignIn(hint: String?) async {
    do {
      let email = try await source.signIn(hint: hint, existing: config.accounts.map(\.email))
      guard !Task.isCancelled else { return }
      signInTask = nil
      isSigningIn = false
      updateConfig { $0.addAccount(email) }
      accountStates[email] = .ok
      lastError = nil
      await refresh()
    } catch {
      guard !Task.isCancelled else { return }
      signInTask = nil
      isSigningIn = false
      lastError = error.localizedDescription
    }
  }

  /// Removes the account from every Mac (through the shared config) and drops what this Mac holds for it.
  func remove(account: String) {
    // The account still leaves every Mac; the user is told this Mac kept its grant.
    do {
      try source.forget(account)
    } catch {
      lastError = String(localized: "Could not remove this Mac's sign-in for \(account): \(error.localizedDescription)")
    }
    accountStates[account] = nil
    calendars[account] = nil
    lastFetched[account] = nil
    updateConfig { $0.removeAccount(account) }
    meetings.removeAll { $0.account == account }
  }

  // MARK: Meetings

  func refresh() async {
    guard !isRefreshing else {
      // A settings change during a fetch must not be lost to the fetch in flight.
      refreshAgain = true
      return
    }
    isRefreshing = true
    defer {
      isRefreshing = false
      if refreshAgain {
        refreshAgain = false
        Task { await refresh() }
      }
    }

    reloadConfigFromDisk()
    let window = ReadWindow(now: Date())

    var lists: [[Meeting]] = []
    var states: [String: AccountState] = [:]
    var fetchedCalendars: [String: [CalendarRef]] = [:]
    var usedCalendars: [String: [CalendarRef]] = [:]
    for account in config.accounts {
      do {
        let all = try await source.calendars(account: account.email)
        fetchedCalendars[account.email] = all
        let used = all.filter(account.uses)
        let fetched = try await source.meetings(
          account: account.email, calendars: used, from: window.from, to: window.to)
        usedCalendars[account.email] = used
        lastFetched[account.email] = fetched
        lists.append(fetched)
        states[account.email] = .ok
      } catch CalendarError.needsSignIn {
        states[account.email] = .needsSignIn
      } catch {
        // Keep what we already know so cut-ins still fire while offline, but
        // honour the calendar choice made since.
        let known = calendars[account.email] ?? []
        lists.append((lastFetched[account.email] ?? []).filter { account.uses($0, among: known) })
        fetchedCalendars[account.email] = calendars[account.email]
        states[account.email] = .error(error.localizedDescription)
      }
    }
    // An account removed while its fetch was in flight must not come back.
    let current = Set(config.accounts.map(\.email))
    meetings = Meeting.merge(lists.map { $0.filter { current.contains($0.account) } })
    calendars = fetchedCalendars.filter { current.contains($0.key) }
    accountStates = states.filter { current.contains($0.key) }
    // An account added while the fetch was in flight has not been read yet.
    let readAll = !config.accounts.isEmpty && config.accounts.allSatisfy { accountStates[$0.email] == .ok }
    if readAll {
      lastReadAt = Date()
      calendarsRead = usedCalendars.values.map(\.count).reduce(0, +)
    }
    lookahead =
      readAll && window.needsLookahead(after: meetings, now: Date())
      ? await lookAhead(past: window, on: usedCalendars) : nil
  }

  /// Searches past `window` for the next meeting. Nil when an account cannot be
  /// searched, since a meeting it holds might come first.
  private func lookAhead(past window: ReadWindow, on calendars: [String: [CalendarRef]]) async -> Lookahead? {
    var found: [[Meeting]] = []
    for (account, used) in calendars {
      guard
        let meetings = try? await source.meetings(
          account: account, calendars: used, from: window.to, to: window.lookaheadEnd)
      else { return nil }
      found.append(meetings)
    }
    let current = Set(config.accounts.map(\.email))
    let next = window.firstAfter(Meeting.merge(found).filter { current.contains($0.account) })
    return Lookahead(next: next, lastDay: window.lastLookaheadDay)
  }

  /// Reads the meetings of `interval` for the menu's calendar, replacing a read still
  /// in flight for another one. A failed read leaves the last one in place, so the
  /// days it does not cover read as unknown rather than as empty.
  func readPeriod(_ interval: DateInterval) {
    periodTask?.cancel()
    isReadingPeriod = true
    periodTask = Task {
      var lists: [[Meeting]] = []
      for account in config.accounts where state(of: account.email) == .ok {
        do {
          let all: [CalendarRef]
          if let known = calendars[account.email] {
            all = known
          } else {
            all = try await source.calendars(account: account.email)
          }
          lists.append(
            try await source.meetings(
              account: account.email, calendars: all.filter(account.uses), from: interval.start, to: interval.end))
        } catch {
          guard !Task.isCancelled else { return }
          isReadingPeriod = false
          return
        }
      }
      guard !Task.isCancelled else { return }
      let current = Set(config.accounts.map(\.email))
      periodRead = PeriodRead(
        interval: interval, meetings: Meeting.merge(lists.map { $0.filter { current.contains($0.account) } }))
      isReadingPeriod = false
    }
  }

  /// Drops what was read for the menu's calendar once the menu closes, so the next
  /// opening shows its days as loading until they are read again, not as they were.
  func endPeriodRead() {
    periodTask?.cancel()
    periodTask = nil
    periodRead = nil
    isReadingPeriod = false
  }

  // MARK: Acknowledgements

  /// Meeting occurrences the user has joined or dismissed, persisted so a relaunch
  /// does not interrupt again.
  var acknowledged: Set<String> {
    Set((UserDefaults.standard.dictionary(forKey: Self.acknowledgedKey) ?? [:]).keys)
  }

  func acknowledge(_ meetings: [Meeting]) {
    var stored = UserDefaults.standard.dictionary(forKey: Self.acknowledgedKey) as? [String: Double] ?? [:]
    for m in meetings { stored[m.acknowledgementKey] = m.start.timeIntervalSince1970 }
    let cutoff = Date().addingTimeInterval(-2 * 24 * 3600).timeIntervalSince1970
    stored = stored.filter { $0.value > cutoff }
    UserDefaults.standard.set(stored, forKey: Self.acknowledgedKey)
  }
}
