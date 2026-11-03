import AppKit
import Testing

@testable import Calendrop

@Suite(.serialized) @MainActor struct MenuCalendarLayoutTests {
  @Test func selectingAnEmptyOrBusyDayKeepsTheMenuWidth() {
    _ = NSApplication.shared
    let menu = NSMenu()
    let calendar = NSMenuItem()
    calendar.view = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 250))
    menu.addItem(calendar)
    let row = NSMenuItem(title: "No meetings", action: nil, keyEquivalent: "")
    menu.addItem(row)
    MenuCalendarLayout.fit(menu)
    let emptyWidth = menu.size.width

    row.title = "09:00  " + String(repeating: "A long meeting title 日本語 👩🏽‍💻 ", count: 8)
    let fullTitle = row.title
    row.submenu = NSMenu()
    if #available(macOS 14.4, *) {
      row.subtitle = String(repeating: "Accepted · Work account · Calendar ", count: 10)
    }
    MenuCalendarLayout.fit(menu)
    #expect(menu.size.width == emptyWidth)
    #expect(row.title.hasSuffix("…"))
    #expect(row.toolTip == fullTitle)
    #expect(row.submenu != nil)

    row.title = "No meetings"
    row.submenu = nil
    if #available(macOS 14.4, *) { row.subtitle = nil }
    MenuCalendarLayout.fit(menu)
    #expect(menu.size.width == emptyWidth)
  }
}
