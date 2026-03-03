// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RemoteSecretProtocol",
    platforms: [
        .iOS(.v17),
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
                .product(name: "ThreemaEssentialsTestHelper", package: "ThreemaEssentials"),
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
