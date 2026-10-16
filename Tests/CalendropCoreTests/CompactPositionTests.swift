import CoreGraphics
import Foundation
import Testing

@testable import CalendropCore

@Suite struct CompactPositionTests {
  // A 1000×800 screen whose menu bar takes the top 30 points and whose Dock takes the bottom 50.
  let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
  let visible = CGRect(x: 0, y: 50, width: 1000, height: 720)
  let card = CGSize(width: 400, height: 100)

  @Test func sitsAtTheTopCentreByDefault() {
    #expect(CutinAppearance().compactPosition == .top)
  }

  @Test(
    arguments: [
      (CompactPosition.topLeading, CGPoint(x: 16, y: 654)),
      (.top, CGPoint(x: 300, y: 654)),
      (.topTrailing, CGPoint(x: 584, y: 654)),
      (.bottomLeading, CGPoint(x: 16, y: 66)),
      (.bottom, CGPoint(x: 300, y: 66)),
      (.bottomTrailing, CGPoint(x: 584, y: 66)),
    ])
  func keepsClearOfTheMenuBarAndTheDock(position: CompactPosition, origin: CGPoint) {
    #expect(position.frame(of: card, in: visible, margin: 16) == CGRect(origin: origin, size: card))
  }

  @Test(arguments: [CompactPosition.topLeading, .top, .topTrailing])
  func entersFromAboveTheScreenWhenAtTheTop(position: CompactPosition) {
    let placed = position.frame(of: card, in: visible, margin: 16)
    let entrance = position.entranceFrame(of: card, in: visible, screen: screen, margin: 16)
    #expect(entrance.minY == screen.maxY)
    #expect(entrance.minX == placed.minX)
  }

  @Test(arguments: [CompactPosition.bottomLeading, .bottom, .bottomTrailing])
  func entersFromBelowTheScreenWhenAtTheBottom(position: CompactPosition) {
    let placed = position.frame(of: card, in: visible, margin: 16)
    let entrance = position.entranceFrame(of: card, in: visible, screen: screen, margin: 16)
    #expect(entrance.maxY == screen.minY)
    #expect(entrance.minX == placed.minX)
  }

  @Test func roundTripsThroughJSONAndReadsAnUnknownOneAsTheDefault() throws {
    var appearance = CutinAppearance()
    appearance.compactPosition = .bottomLeading
    let decoded = try JSONDecoder().decode(CutinAppearance.self, from: JSONEncoder().encode(appearance))
    #expect(decoded.compactPosition == .bottomLeading)
    let unknown = try JSONDecoder().decode(CutinAppearance.self, from: Data(#"{"compactPosition":"middle"}"#.utf8))
    #expect(unknown.compactPosition == .top)
    let legacy = try JSONDecoder().decode(CutinAppearance.self, from: Data(#"{"style":"ocean"}"#.utf8))
    #expect(legacy.compactPosition == .top)
  }
}
