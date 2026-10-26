// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Calendrop",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Calendrop", targets: ["Calendrop"])
  ],
  targets: [
    .target(name: "CalendropCore", resources: [.process("Localizable.xcstrings")]),
    .executableTarget(
      name: "Calendrop",
      dependencies: ["CalendropCore"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(name: "CalendropCoreTests", dependencies: ["CalendropCore"]),
    .testTarget(name: "CalendropTests", dependencies: ["Calendrop"]),
  ]
)
