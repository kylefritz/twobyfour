// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "twobyfour",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "TwoByFourEngine", targets: ["TwoByFourEngine"]),
        .library(name: "TwoByFourKit", targets: ["TwoByFourKit"]),
        .executable(name: "twobyfour", targets: ["twobyfour"]),
    ],
    targets: [
        // The calculator itself: no UI, so the iPhone app can share it later.
        .target(name: "TwoByFourEngine"),
        // Logic that isn't UI: sheet storage and logs (Mac and iPhone), the updater (Mac).
        .target(name: "TwoByFourKit", dependencies: ["TwoByFourEngine"]),
        .executableTarget(name: "twobyfour", dependencies: ["TwoByFourEngine", "TwoByFourKit"]),
        .testTarget(name: "TwoByFourEngineTests", dependencies: ["TwoByFourEngine"]),
        .testTarget(name: "TwoByFourKitTests", dependencies: ["TwoByFourKit"]),
    ],
    swiftLanguageModes: [.v5]
)
