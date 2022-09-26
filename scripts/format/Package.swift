// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Format",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.49.7"),
    ],
    targets: [
        .target(name: "Format", path: ""),
    ]
)
