import Foundation
import Testing

@testable import CalendropCore

@Suite struct CutinSoundTests {
  @Test func offersSilenceFirstAndThenTheSoundsOfMacOS() {
    #expect(CutinSound.choices.first == CutinSound.none)
    #expect(CutinSound.choices.dropFirst().allSatisfy { $0.systemName != nil })
    #expect(CutinSound.choices.contains(CutinSound(systemName: "Glass")))
    #expect(CutinSound.none.systemName == nil)
  }

  @Test func playsNothingByDefaultSoAnUpdateDoesNotStartMakingNoise() throws {
    #expect(SharedConfig().cutInSound == .none)
    let older = try JSONDecoder().decode(SharedConfig.self, from: Data("{}".utf8))
    #expect(older.cutInSound == .none)
  }

  @Test func roundTripsThroughTheSharedConfig() throws {
    var config = SharedConfig()
    config.cutInSound = CutinSound(systemName: "Hero")
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded.cutInSound == CutinSound(systemName: "Hero"))
    config.cutInSound = .none
    let silent = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(silent.cutInSound == .none)
  }

  @Test func keepsASoundAnotherMacOrALaterMacOSOffers() throws {
    let config = try JSONDecoder().decode(SharedConfig.self, from: Data(#"{"cutInSound":"Chime"}"#.utf8))
    #expect(config.cutInSound == CutinSound(systemName: "Chime"))
  }

  @Test func anUnreadableSoundFallsBackToSilenceWithoutLosingTheRest() throws {
    let config = try JSONDecoder().decode(
      SharedConfig.self, from: Data(#"{"cutInSound":42,"leadMinutes":5}"#.utf8))
    #expect(config.cutInSound == .none)
    #expect(config.leadMinutes == 5)
  }

  @Test(arguments: [CutinPresentation.fullScreen, .compact])
  func soundsWhenAMeetingComesDueOnScreen(_ presentation: CutinPresentation) {
    #expect(CutinSound(systemName: "Glass").plays(arriving: true, as: presentation))
  }

  @Test func staysQuietWhenNothingNewComesDue() {
    for presentation in CutinPresentation.allCases {
      #expect(!CutinSound(systemName: "Glass").plays(arriving: false, as: presentation))
    }
  }

  @Test func staysQuietForACutInHeldBackDuringACall() {
    #expect(!CutinSound(systemName: "Glass").plays(arriving: true, as: .hidden))
  }

  @Test func silenceNeverPlays() {
    for presentation in CutinPresentation.allCases {
      #expect(!CutinSound.none.plays(arriving: true, as: presentation))
    }
  }
}
