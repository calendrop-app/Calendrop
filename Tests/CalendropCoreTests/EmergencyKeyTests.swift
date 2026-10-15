import Testing

@testable import CalendropCore

@Suite struct EmergencyKeyTests {
  private let escape = EmergencyKey.keyCode

  @Test func closesOnControlOptionCommandEscape() {
    #expect(EmergencyKey.matches(keyCode: escape, modifiers: [.control, .option, .command]))
  }

  @Test func ignoresCapsLockAndTheFunctionKey() {
    #expect(EmergencyKey.matches(keyCode: escape, modifiers: [.control, .option, .command, .capsLock, .function]))
  }

  @Test(
    arguments: [
      [],
      [.command],
      [.option, .command],
      [.control, .command],
      [.control, .option],
      [.control, .option, .command, .shift],
    ] as [EmergencyKey.Modifiers])
  func ignoresAnyOtherModifiers(modifiers: EmergencyKey.Modifiers) {
    #expect(!EmergencyKey.matches(keyCode: escape, modifiers: modifiers))
  }

  @Test func ignoresOtherKeys() {
    #expect(!EmergencyKey.matches(keyCode: 0, modifiers: [.control, .option, .command]))
  }

  @Test func namesTheCombinationForTheUser() {
    #expect(EmergencyKey.symbol == "⌃⌥⌘⎋")
  }
}
