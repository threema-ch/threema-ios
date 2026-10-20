// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "RemoteSecretProtocol",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "RemoteSecretProtocol",
            targets: ["RemoteSecretProtocol"]
        ),
        .library(
            name: "RemoteSecretProtocolTestHelper",
            targets: ["RemoteSecretProtocolTestHelper"]
        ),
    ],
    dependencies: [
        .package(path: "../ThreemaEssentials"),
    ],
    targets: [
        .target(
            name: "RemoteSecretProtocol"
        ),
        .target(
            name: "RemoteSecretProtocolTestHelper",
            dependencies: [
                "RemoteSecretProtocol",
                .product(name: "ThreemaEssentials", package: "ThreemaEssentials"),
            ],
            path: "Tests/Helper"
        ),
        .testTarget(
            name: "RemoteSecretProtocolTests",
            dependencies: ["RemoteSecretProtocol"]
        ),
    ]
)
