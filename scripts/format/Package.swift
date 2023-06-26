// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Format",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", .upToNextMinor(from: "0.51.11")),
    ],
    targets: [
        .target(name: "Format", path: ""),
    ]
)
