import Foundation

public struct MenuBarPreferences: Codable, Equatable, Sendable {
  public enum Visibility: String, Codable, CaseIterable, Sendable {
    case show, hide, toggle
  }

  public enum Privacy: String, Codable, CaseIterable, Sendable {
    case always, never, toggle
  }

  public var visibility = Visibility.show
  public var privacy = Privacy.never
  private var temporarilyHidden = false
  private var temporarilyPrivate = false

  private enum CodingKeys: String, CodingKey {
    case visibility, privacy
  }

  public init() {}

  public var showsMeeting: Bool {
    visibility == .show || (visibility == .toggle && !temporarilyHidden)
  }

  public var hidesTitle: Bool {
    privacy == .always || (privacy == .toggle && temporarilyPrivate)
  }

  public mutating func rightClick() {
    if visibility == .toggle {
      temporarilyHidden.toggle()
    } else if visibility == .show && privacy == .toggle {
      temporarilyPrivate.toggle()
    }
  }
}
