// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "twobyfour",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "TwoByFourEngine", targets: ["TwoByFourEngine"]),
        .executable(name: "twobyfour", targets: ["twobyfour"]),
    ],
    targets: [
        // The calculator itself: no UI, so the iPhone app can share it later.
        .target(name: "TwoByFourEngine"),
        // Mac-only logic that isn't UI: sheet storage, the updater.
        .target(name: "TwoByFourKit", dependencies: ["TwoByFourEngine"]),
        .executableTarget(name: "twobyfour", dependencies: ["TwoByFourEngine", "TwoByFourKit"]),
        .testTarget(name: "TwoByFourEngineTests", dependencies: ["TwoByFourEngine"]),
        .testTarget(name: "TwoByFourKitTests", dependencies: ["TwoByFourKit"]),
    ],
    swiftLanguageModes: [.v5]
)
