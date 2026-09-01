// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "PulseBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "PulseBar", targets: ["PulseBar"])
  ],
  targets: [
    .executableTarget(
      name: "PulseBar",
      path: "Sources/PulseBar"
    ),
    .testTarget(
      name: "PulseBarTests",
      dependencies: ["PulseBar"],
      path: "Tests/PulseBarTests"
    ),
  ]
)
