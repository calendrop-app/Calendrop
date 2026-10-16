import Foundation

/// How a cut-in is put in front of the user.
public enum CutinPresentation: String, Codable, CaseIterable, Sendable {
  /// Every screen covered.
  case fullScreen
  /// A small panel in a corner of the main screen, leaving the call in view.
  case compact
  /// Nothing on screen; the meetings are held until the call ends.
  case hidden
}

/// Decides how a cut-in is shown while the user is already in a call.
public struct CallAwareness: Equatable, Sendable {
  /// How a cut-in that comes due during a call is shown.
  public var duringCall: CutinPresentation
  /// Whether a cut-in held back during a call covers every screen once the call ends.
  public var coverAfterCall: Bool

  public init(duringCall: CutinPresentation, coverAfterCall: Bool) {
    self.duringCall = duringCall
    self.coverAfterCall = coverAfterCall
  }

  /// `showing` is how the cut-in is shown now, nil when none is; `arriving` says that
  /// meetings are joining it. A cut-in covering the screen never shrinks: the user
  /// may be in the middle of reading it.
  public func presentation(inCall: Bool, showing: CutinPresentation?, arriving: Bool) -> CutinPresentation {
    if showing == .fullScreen { return .fullScreen }
    if inCall { return duringCall }
    guard let showing, !arriving else { return .fullScreen }
    return coverAfterCall ? .fullScreen : showing
  }

  /// The meetings a cut-in keeps holding. One held back during a call follows
  /// `latest`, the calendar as last fetched, and lets go of meetings that have ended
  /// or left it, so the end of a call never covers the screen for a meeting already
  /// over; one covering the screen stays as it is until the user acts.
  public func kept(_ meetings: [Meeting], showing: CutinPresentation, now: Date, latest: [Meeting]) -> [Meeting] {
    guard showing != .fullScreen else { return meetings }
    let current = Dictionary(latest.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return meetings.compactMap { current[$0.id] }.filter { $0.end > now }
  }
}

/// Tells when a meeting comes due that the cut-in has not announced yet.
///
/// Being gathered into a cut-in is not arriving: a meeting starting close to the due
/// one joins it early, and must still count as arriving when its own time comes, or
/// one held back during a call would never cover the screen.
public struct ArrivalTracker: Sendable {
  private var announced: Set<String> = []

  public init() {}

  /// `due` is every meeting due now; returns whether any of them is new.
  public mutating func arrive(_ due: [Meeting]) -> Bool {
    let ids = Set(due.map(\.id))
    defer { announced.formUnion(ids) }
    return !ids.isSubset(of: announced)
  }

  public mutating func reset() {
    announced = []
  }
}

/// Tells from the microphone and camera whether the user is in a call.
public struct CallDetector: Sendable {
  /// How long the devices must stay released before the call counts as over, since
  /// call apps briefly let go of them when switching devices or reconnecting.
  public var settle: TimeInterval
  private var lastInUse: Date?

  public init(settle: TimeInterval = 5) {
    self.settle = settle
  }

  public mutating func update(deviceInUse: Bool, now: Date) -> Bool {
    if deviceInUse { lastInUse = now }
    guard let lastInUse else { return false }
    return now.timeIntervalSince(lastInUse) < settle
  }
}
