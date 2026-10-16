import CoreAudio
import CoreMediaIO

/// Whether any app is recording from a microphone or a camera: the sign that the
/// user is in a call, whichever app the call runs in.
///
/// Only reads whether the devices are running, never what they capture, so it needs
/// no microphone or camera permission.
enum CaptureDevices {
  static var inUse: Bool { microphoneInUse || cameraInUse }

  /// Asks each process rather than each device where macOS can (14.2 and later): a
  /// headset's device also runs while it only plays sound, which is not a call.
  /// Earlier systems fall back to the devices, accepting that false alarm over
  /// missing every audio-only call.
  private static var microphoneInUse: Bool {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var processList = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(system, &processList) else {
      return audioArray(system, kAudioHardwarePropertyDevices).contains { device in
        hasInput(device) && flag(device, kAudioDevicePropertyDeviceIsRunningSomewhere)
      }
    }
    return audioArray(system, kAudioHardwarePropertyProcessObjectList).contains { process in
      flag(process, kAudioProcessPropertyIsRunningInput)
    }
  }

  private static func flag(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr && value != 0
  }

  private static func hasInput(_ device: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
  }

  private static var cameraInUse: Bool {
    var address = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    let system = CMIOObjectID(kCMIOObjectSystemObject)
    var size: UInt32 = 0
    guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
    var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
    var used: UInt32 = 0
    guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }
    return devices.contains { device in
      var running = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
      var value: UInt32 = 0
      var valueUsed: UInt32 = 0
      return CMIOObjectGetPropertyData(
        device, &running, 0, nil, UInt32(MemoryLayout<UInt32>.size), &valueUsed, &value) == noErr && value != 0
    }
  }

  private static func audioArray(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
      mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
  }
}
