// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RemoteSecret",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "RemoteSecret",
            targets: ["RemoteSecret"]
        ),
    ],
    dependencies: [
        .package(path: "../RemoteSecretProtocol"),
        .package(path: "../Keychain"),
        .package(path: "../libthreemaSwift"),
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.8.5"),
    ],
    targets: [
        .target(
            name: "RemoteSecret",
            dependencies: [
                "RemoteSecretProtocol",
                "Keychain",
                "libthreemaSwift",
                "ThreemaEssentials",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "RemoteSecretTests",
            dependencies: [
                "RemoteSecret",
                .product(name: "RemoteSecretProtocolTestHelper", package: "RemoteSecretProtocol"),
                .product(name: "KeychainTestHelper", package: "Keychain"),
                .product(name: "libthreemaSwiftTestHelper", package: "libthreemaSwift"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
