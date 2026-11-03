import Foundation
import Testing

@testable import CalendropCore

struct MenuBarPreferencesTests {
  @Test func defaultsPreserveVisibleMeetingTitles() {
    let settings = MenuBarPreferences()
    #expect(settings.showsMeeting)
    #expect(!settings.hidesTitle)
  }

  @Test func rightClickTogglesVisibilityBeforePrivacy() {
    var settings = MenuBarPreferences()
    settings.visibility = .toggle
    settings.privacy = .toggle
    settings.rightClick()
    #expect(!settings.showsMeeting)
    #expect(!settings.hidesTitle)
    settings.rightClick()
    #expect(settings.showsMeeting)
  }

  @Test func privacyToggleRetainsCountdownAndDoesNothingWhileHidden() {
    var settings = MenuBarPreferences()
    settings.privacy = .toggle
    settings.rightClick()
    #expect(settings.hidesTitle)
    #expect(settings.showsMeeting)
    settings.visibility = .hide
    settings.rightClick()
    settings.visibility = .show
    #expect(settings.hidesTitle)
  }

  @Test func fixedChoicesIgnoreTransientToggles() {
    var settings = MenuBarPreferences()
    settings.visibility = .hide
    settings.privacy = .always
    settings.rightClick()
    #expect(!settings.showsMeeting)
    #expect(settings.hidesTitle)
  }

  @Test func transientChoicesAreNotPersisted() throws {
    var settings = MenuBarPreferences()
    settings.visibility = .toggle
    settings.rightClick()
    let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: JSONEncoder().encode(settings))
    #expect(decoded.showsMeeting)
  }
}
