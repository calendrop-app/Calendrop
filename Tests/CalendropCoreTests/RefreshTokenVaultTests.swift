import Foundation
import Testing

@testable import CalendropCore

/// Storage kept in memory, counting the reads that would each ask the user.
private final class FakeStorage: RefreshTokenStorage {
  var item: Data?
  var reads = 0
  var denied = false
  var unavailable = false
  var failsWrite = false

  struct Failure: Error {}

  func read() throws -> Data? {
    reads += 1
    if denied { throw RefreshTokenStorageError.refused }
    if unavailable { throw Failure() }
    return item
  }

  func write(_ data: Data) throws {
    if failsWrite { throw Failure() }
    item = data
  }
}

@Suite struct RefreshTokenVaultTests {
  @Test func readsTheStorageOnceHoweverManyAccountsAreAskedFor() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    try RefreshTokenVault(storage: storage).set("t2", for: "b@example.com")
    storage.reads = 0

    let vault = RefreshTokenVault(storage: storage)
    #expect(try vault.token(for: "a@example.com") == "t1")
    #expect(try vault.token(for: "b@example.com") == "t2")
    #expect(try vault.token(for: "c@example.com") == nil)
    #expect(storage.reads == 1)
  }

  @Test func keepsEveryAccountInOneItem() throws {
    let storage = FakeStorage()
    let vault = RefreshTokenVault(storage: storage)
    try vault.set("t1", for: "a@example.com")
    try vault.set("t2", for: "b@example.com")
    try vault.remove("a@example.com")

    let reopened = RefreshTokenVault(storage: storage)
    #expect(try reopened.token(for: "a@example.com") == nil)
    #expect(try reopened.token(for: "b@example.com") == "t2")
  }

  @Test func matchesAddressesWithoutRegardToCase() throws {
    let vault = RefreshTokenVault(storage: FakeStorage())
    try vault.set("t1", for: "Me@Example.com")
    #expect(try vault.token(for: "me@example.com") == "t1")
    try vault.remove("ME@EXAMPLE.COM")
    #expect(try vault.token(for: "me@example.com") == nil)
  }

  @Test func treatsAnUnreadableItemAsHoldingNoToken() throws {
    let storage = FakeStorage()
    storage.item = Data("not json".utf8)
    let vault = RefreshTokenVault(storage: storage)
    #expect(try vault.token(for: "a@example.com") == nil)
    try vault.set("t1", for: "a@example.com")
    #expect(try RefreshTokenVault(storage: storage).token(for: "a@example.com") == "t1")
  }

  @Test func neverOverwritesTheItemItCouldNotRead() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    storage.denied = true

    let vault = RefreshTokenVault(storage: storage)
    #expect(throws: (any Error).self) { try vault.token(for: "a@example.com") }
    #expect(throws: (any Error).self) { try vault.set("t2", for: "b@example.com") }

    storage.denied = false
    let reopened = RefreshTokenVault(storage: storage)
    #expect(try reopened.token(for: "a@example.com") == "t1")
    #expect(try reopened.token(for: "b@example.com") == nil)
  }

  @Test func asksNoMoreAfterTheUserTurnsTheReadDown() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    storage.denied = true
    storage.reads = 0

    let vault = RefreshTokenVault(storage: storage)
    #expect(throws: (any Error).self) { try vault.token(for: "a@example.com") }
    #expect(throws: (any Error).self) { try vault.token(for: "b@example.com") }
    #expect(throws: (any Error).self) { try vault.token(for: "a@example.com") }
    #expect(storage.reads == 1)
  }

  @Test func triesAgainAfterAReadThatFailedOnItsOwn() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    storage.unavailable = true
    let vault = RefreshTokenVault(storage: storage)
    #expect(throws: (any Error).self) { try vault.token(for: "a@example.com") }

    storage.unavailable = false
    #expect(try vault.token(for: "a@example.com") == "t1")
  }

  @Test func asksAgainWhenTheUserSignsIn() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    storage.denied = true
    let vault = RefreshTokenVault(storage: storage)
    #expect(throws: (any Error).self) { try vault.token(for: "a@example.com") }

    storage.denied = false
    try vault.set("t2", for: "b@example.com")
    #expect(try vault.token(for: "a@example.com") == "t1")
    #expect(try vault.token(for: "b@example.com") == "t2")
  }

  @Test func reportsARemovalItCouldNotMake() throws {
    let storage = FakeStorage()
    try RefreshTokenVault(storage: storage).set("t1", for: "a@example.com")
    storage.denied = true

    #expect(throws: (any Error).self) { try RefreshTokenVault(storage: storage).remove("a@example.com") }
  }
}
