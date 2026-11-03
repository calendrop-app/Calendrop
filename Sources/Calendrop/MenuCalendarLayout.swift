import AppKit

@MainActor
enum MenuCalendarLayout {
  static let width: CGFloat = 350

  /// NSMenu sizes itself from every native row, including subtitles. Keep room for
  /// icons, state marks and submenu arrows so changing days cannot resize the grid.
  static func fit(_ menu: NSMenu) {
    menu.minimumWidth = width
    for item in menu.items where item.view == nil && !item.isSeparatorItem {
      let title = clipped(item.title, font: menu.font)
      if title != item.title {
        if item.toolTip == nil { item.toolTip = item.title }
        item.title = title
      }
      if #available(macOS 14.4, *), let subtitle = item.subtitle {
        item.subtitle = clipped(subtitle, font: menu.font)
      }
    }
  }

  private static func clipped(_ text: String, font: NSFont) -> String {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let available = width - 90
    guard (text as NSString).size(withAttributes: attributes).width > available else { return text }
    var prefix = text
    while !prefix.isEmpty {
      prefix.removeLast()
      if ((prefix + "…") as NSString).size(withAttributes: attributes).width <= available {
        return prefix + "…"
      }
    }
    return "…"
  }
}
