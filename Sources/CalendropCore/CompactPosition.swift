import CoreGraphics

/// Where on each screen the compact cut-in card sits.
public enum CompactPosition: String, Codable, CaseIterable, Sendable {
  case topLeading, top, topTrailing
  case bottomLeading, bottom, bottomTrailing

  private var isTop: Bool { [.topLeading, .top, .topTrailing].contains(self) }

  /// Within `visible`, the screen less the menu bar and the Dock, so the card never
  /// hides behind either.
  public func frame(of size: CGSize, in visible: CGRect, margin: CGFloat) -> CGRect {
    let x: CGFloat =
      switch self {
      case .topLeading, .bottomLeading: visible.minX + margin
      case .top, .bottom: visible.midX - size.width / 2
      case .topTrailing, .bottomTrailing: visible.maxX - size.width - margin
      }
    let y = isTop ? visible.maxY - size.height - margin : visible.minY + margin
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  /// Just past the nearer edge of the whole screen, straight above or below where the
  /// card settles, so it slides in from that edge.
  public func entranceFrame(of size: CGSize, in visible: CGRect, screen: CGRect, margin: CGFloat) -> CGRect {
    var frame = frame(of: size, in: visible, margin: margin)
    frame.origin.y = isTop ? screen.maxY : screen.minY - size.height
    return frame
  }
}
