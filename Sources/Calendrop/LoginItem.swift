import Foundation
import ServiceManagement

/// Whether Calendrop opens when the user logs in to this Mac.
///
/// macOS keeps the answer, in System Settings' Login Items, rather than Calendrop
/// keeping its own copy: the user can change it there too, and a copy would drift.
/// It belongs to the Mac, not to the settings shared through iCloud Drive.
@MainActor
enum LoginItem {
  enum State: Equatable {
    case on
    case off
    /// Turned on, but the user has yet to allow it in System Settings.
    case needsApproval
  }

  /// `.notFound` is not taken to mean Calendrop cannot be registered: macOS also
  /// reports it for an app that has never been, so it reads as off, and a
  /// registration that really fails says why when it is tried.
  static var state: State {
    switch SMAppService.mainApp.status {
    case .enabled: .on
    case .requiresApproval: .needsApproval
    case .notRegistered, .notFound: .off
    @unknown default: .off
    }
  }

  static func set(_ on: Bool) throws {
    if on {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }

  static func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
