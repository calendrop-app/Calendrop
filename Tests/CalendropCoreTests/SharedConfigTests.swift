import Foundation
import Testing

@testable import CalendropCore

@Suite struct SharedConfigTests {
  private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  @Test func missingFileYieldsDefaults() throws {
    let store = ConfigStore(url: try tempDir().appendingPathComponent("nested/config.json"))
    #expect(store.load() == SharedConfig())
    #expect(SharedConfig().leadMinutes == 2)
  }

  @Test func roundTripsAndCreatesDirectories() throws {
    let store = ConfigStore(url: try tempDir().appendingPathComponent("nested/config.json"))
    var config = SharedConfig()
    config.addAccount("a@example.com")
    config.addAccount("b@example.com")
    config.setLeadMinutes(5)
    try store.save(config)
    #expect(store.load() == config)
  }

  @Test func toleratesMissingAndUnknownKeys() throws {
    let url = try tempDir().appendingPathComponent("config.json")
    try Data(#"{"accounts":[{"email":"a@example.com"}],"clientID":"left over","futureKey":1}"#.utf8).write(to: url)
    let config = ConfigStore(url: url).load()
    #expect(config.accounts.map(\.email) == ["a@example.com"])
    #expect(config.leadMinutes == 2)
  }

  @Test func cutsInOnlyForMeetingsWithAJoinLinkByDefault() throws {
    #expect(SharedConfig().cutInWithoutJoinLink == false)
    var config = SharedConfig()
    config.cutInWithoutJoinLink = true
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded.cutInWithoutJoinLink)
  }

  @Test func cutsInForMeetingsNotYetAcceptedByDefault() throws {
    #expect(SharedConfig().cutInWithoutAcceptance)
    let older = try JSONDecoder().decode(SharedConfig.self, from: Data("{}".utf8))
    #expect(older.cutInWithoutAcceptance)
    var config = SharedConfig()
    config.cutInWithoutAcceptance = false
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(!decoded.cutInWithoutAcceptance)
  }

  @Test func shrinksTheCutInDuringACallAndCoversOnceItEndsByDefault() throws {
    let older = try JSONDecoder().decode(SharedConfig.self, from: Data("{}".utf8))
    #expect(older.callAwareness == CallAwareness(duringCall: .compact, coverAfterCall: true))
    #expect(SharedConfig().callAwareness == older.callAwareness)
  }

  @Test func roundTripsTheCutInDuringACall() throws {
    var config = SharedConfig()
    config.cutInDuringCall = .hidden
    config.coverAfterCall = false
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded.callAwareness == CallAwareness(duringCall: .hidden, coverAfterCall: false))
  }

  @Test func readsAnUnknownCutInDuringACallAsTheDefault() throws {
    let config = try JSONDecoder().decode(SharedConfig.self, from: Data(#"{"cutInDuringCall":"sideways"}"#.utf8))
    #expect(config.cutInDuringCall == SharedConfig().cutInDuringCall)
  }

  @Test func neverStoresTokensOrClientCredentials() throws {
    let encoded = String(decoding: try JSONEncoder().encode(SharedConfig()), as: UTF8.self).lowercased()
    #expect(!encoded.contains("token"))
    #expect(!encoded.contains("client"))
  }

  @Test func addingAccountIsCaseInsensitiveAndIdempotent() {
    var config = SharedConfig()
    config.addAccount("Me@Example.com")
    config.addAccount("me@example.com")
    #expect(config.accounts.map(\.email) == ["me@example.com"])
    config.removeAccount("ME@example.com")
    #expect(config.accounts.isEmpty)
  }

  @Test func prefersICloudDriveWhenPresent() throws {
    let home = try tempDir()
    #expect(ConfigStore.defaultURL(home: home).path.contains("Application Support/Calendrop"))
    let cloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
    #expect(ConfigStore.defaultURL(home: home) == cloud.appendingPathComponent("Calendrop/config.json"))
  }

  @Test func aFileStoreSaysWhereItKeepsTheSettings() throws {
    let url = try tempDir().appendingPathComponent("config.json")
    #expect(ConfigStore(url: url).location == url)
  }

  @Test func aMemoryStoreKeepsSettingsOnlyForItsLifetime() throws {
    let store = MemoryConfigStore()
    #expect(store.location == nil)
    #expect(store.load() == SharedConfig())
    var config = SharedConfig()
    config.addAccount("a@example.com")
    try store.save(config)
    #expect(store.load() == config)
    #expect(MemoryConfigStore().load() == SharedConfig())
  }
}

@Suite struct LeadMinutesTests {
  @Test(arguments: [(-5, 0), (0, 0), (7, 7), (120, 120), (500, 120)] as [(Int, Int)])
  func clampsTypedLeadTimes(typed: Int, stored: Int) {
    var config = SharedConfig()
    config.setLeadMinutes(typed)
    #expect(config.leadMinutes == stored)
  }

  @Test func clampsAHandEditedFile() throws {
    let config = try JSONDecoder().decode(SharedConfig.self, from: Data(#"{"leadMinutes":-3}"#.utf8))
    #expect(config.leadMinutes == 0)
  }
}
