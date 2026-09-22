// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "GroupCalls",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GroupCalls",
            targets: ["GroupCalls"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(path: "../AudioSessionManager"),
        .package(path: "../ThreemaProtocols"),
        .package(path: "../ThreemaBlake2b"),
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.38.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.9.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GroupCalls",
            dependencies: [
                "ThreemaProtocols",
                "ThreemaBlake2b",
                "ThreemaEssentials",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "AudioSessionManager", package: "AudioSessionManager"),
                .product(name: "WebRTC", package: "AudioSessionManager"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-warn-long-function-bodies=100",
                    "-Xfrontend", "-warn-long-expression-type-checking=100",
                ]),
            ]
        ),
        .testTarget(
            name: "GroupCallsTests",
            dependencies: [
                "GroupCalls",
                .product(name: "AudioSessionManagerTestHelper", package: "AudioSessionManager"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5],
)
