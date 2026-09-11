// swift-tools-version: 6.2
// Author: Zeno Ren
import PackageDescription

let package = Package(
    name: "UsageTracking",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "UsageTracking", targets: ["UsageTracking"]),
        .executable(name: "usage-tracking", targets: ["UsageTrackingCLI"]),
        .library(name: "UsageCore", targets: ["UsageCore"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(name: "UsageCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "UsageTracking", dependencies: ["UsageCore"], resources: [.copy("Assets")]),
        .executableTarget(name: "UsageTrackingCLI", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageTrackingTests", dependencies: ["UsageTracking"])
    ]
)
