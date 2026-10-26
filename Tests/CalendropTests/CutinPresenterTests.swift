import AppKit
import CalendropCore
import Testing

@testable import Calendrop

@Suite(.serialized) @MainActor struct CutinPresenterTests {
  @Test func compactCreatesANonactivatingPanelForEveryScreen() throws {
    _ = NSApplication.shared
    let screen = try #require(NSScreen.screens.first)
    let presenter = CutinPresenter(screens: { [screen, screen] })
    presenter.dropsIn = false
    defer { presenter.hide() }

    presenter.show(SampleCalendar.Scenario.single.meetings(now: .now, leadTime: 0), as: .compact)

    #expect(presenter.windows.count == 2)
    for panel in presenter.windows {
      #expect(panel.isVisible)
      #expect(panel.styleMask.contains(.nonactivatingPanel))
      #expect(!panel.canBecomeKey)
      #expect(!panel.canBecomeMain)
      #expect(panel.frame.midX == screen.visibleFrame.midX)
      #expect(panel.frame.maxY == screen.visibleFrame.maxY - 4)
    }
  }

  @Test func compactFollowsScreenChangesAndHidesEveryPanel() throws {
    _ = NSApplication.shared
    let screen = try #require(NSScreen.screens.first)
    var screens = [screen]
    let presenter = CutinPresenter(screens: { screens })
    presenter.dropsIn = false
    defer { presenter.hide() }
    presenter.show(SampleCalendar.Scenario.single.meetings(now: .now, leadTime: 0), as: .compact)

    screens = [screen, screen]
    presenter.syncWithScreens(force: false)
    #expect(presenter.windows.count == 2)
    let panels = presenter.windows

    screens = [screen]
    presenter.syncWithScreens(force: false)
    #expect(presenter.windows.count == 1)
    #expect(panels.allSatisfy { !$0.isVisible })
    let remaining = presenter.windows

    presenter.hide()
    #expect(presenter.windows.isEmpty)
    #expect(remaining.allSatisfy { !$0.isVisible })
  }
}
