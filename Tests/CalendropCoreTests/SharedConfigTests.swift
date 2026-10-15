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
    config.accounts = ["a@example.com", "b@example.com"]
    config.leadMinutes = 5
    try store.save(config)
    #expect(store.load() == config)
  }

  @Test func toleratesMissingAndUnknownKeys() throws {
    let url = try tempDir().appendingPathComponent("config.json")
    try Data(#"{"accounts":["a@example.com"],"clientID":"left over","futureKey":1}"#.utf8).write(to: url)
    let config = ConfigStore(url: url).load()
    #expect(config.accounts == ["a@example.com"])
    #expect(config.leadMinutes == 2)
  }

  @Test func cutsInOnlyForMeetingsWithAJoinLinkByDefault() throws {
    #expect(SharedConfig().cutInWithoutJoinLink == false)
    var config = SharedConfig()
    config.cutInWithoutJoinLink = true
    let decoded = try JSONDecoder().decode(SharedConfig.self, from: JSONEncoder().encode(config))
    #expect(decoded.cutInWithoutJoinLink)
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
    #expect(config.accounts == ["me@example.com"])
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
}
