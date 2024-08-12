// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Format",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", .upToNextMinor(from: "0.54.0")),
    ],
    targets: [
        .target(name: "Format", path: ""),
    ]
)
