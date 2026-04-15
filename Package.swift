// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleNote",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "SimpleNote", path: "Sources/SimpleNote")
    ]
)
