// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Keychain",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "Keychain",
            targets: ["Keychain"]
        ),
        .library(
            name: "KeychainTestHelper",
            targets: ["KeychainTestHelper"]
        ),
    ],
    dependencies: [
        .package(path: "../RemoteSecretProtocol"),
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.8.5"),
    ],
    targets: [
        .target(
            name: "Keychain",
            dependencies: [
                "RemoteSecretProtocol",
                "ThreemaEssentials",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ]
        ),
        .target(
            name: "KeychainTestHelper",
            dependencies: [
                "Keychain",
                .product(name: "ThreemaEssentialsTestHelper", package: "ThreemaEssentials"),
            ],
            path: "Tests/Helper"
        ),
        .testTarget(
            name: "KeychainTests",
            dependencies: [
                "Keychain",
                "KeychainTestHelper",
                .product(name: "RemoteSecretProtocolTestHelper", package: "RemoteSecretProtocol"),
            ]
        ),
    ]
)
