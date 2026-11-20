import AppKit
import CalendropCore

extension CutinSound {
  /// A sound this Mac does not have plays nothing rather than failing: the choice may
  /// have come from another Mac through the shared settings.
  @MainActor func play() {
    guard let systemName, let sound = NSSound(named: NSSound.Name(systemName)) else { return }
    sound.stop()
    sound.play()
  }
}
