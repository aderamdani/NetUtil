// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "netutil",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "netutil", path: "Sources/netutil")
    ]
)
