// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AudioSessionManager",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "AudioSessionManager",
            targets: ["AudioSessionManager"]
        ),
        .library(
            name: "AudioSessionManagerRTC",
            targets: ["AudioSessionManagerRTC"]
        ),
        .library(
            name: "AudioSessionManagerTestHelper",
            targets: ["AudioSessionManagerTestHelper"]
        ),
        .library(
            name: "WebRTC",
            targets: ["WebRTC"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.9.1"),
    ],
    targets: [
        // Driver for everything that is not a call.
        .target(
            name: "AudioSessionManager",
            dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        // The CallKit-delegated driver.
        .target(
            name: "AudioSessionManagerRTC",
            dependencies: [
                "AudioSessionManager",
                "WebRTC",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .target(
            name: "AudioSessionManagerTestHelper",
            dependencies: ["AudioSessionManager"],
            path: "Tests/Helper",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .binaryTarget(name: "WebRTC", path: "../WebRTC.xcframework"),
        .testTarget(
            name: "AudioSessionManagerTests",
            dependencies: [
                "AudioSessionManager",
                "AudioSessionManagerTestHelper",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
