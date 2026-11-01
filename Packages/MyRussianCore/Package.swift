// swift-tools-version: 6.2
import PackageDescription

// Platform-independent domain logic for My Russian.
// Deliberately Foundation-only so it can be test-driven with `swift test`
// on any machine (including Linux CI) without Xcode or a simulator.
let package = Package(
    name: "MyRussianCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MyRussianCore", targets: ["MyRussianCore"])
    ],
    targets: [
        .target(name: "MyRussianCore"),
        .testTarget(name: "MyRussianCoreTests", dependencies: ["MyRussianCore"])
    ]
)
