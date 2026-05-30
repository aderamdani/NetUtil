// swift-tools-version: 6.0
import PackageDescription

// Clinical test harness for NetUtil.
//
// `Sources/NetUtilCore` contains SYMLINKS to the real app source files
// (../../NetUtil/...), so tests always run against production code with zero
// drift. Only Foundation-level / framework-available files are linked; UI
// (SwiftUI) files are intentionally excluded so the logic compiles headless.
//
// Run:  swift test --package-path tests-spm
let package = Package(
    name: "NetUtilCore",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "NetUtilCore",
            swiftSettings: [.swiftLanguageMode(.v5)]   // mirror the app's SWIFT_VERSION = 5.0
        ),
        .testTarget(
            name: "NetUtilCoreTests",
            dependencies: ["NetUtilCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
