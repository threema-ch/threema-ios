// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ThreemaProtocols",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ThreemaProtocols",
            targets: ["ThreemaProtocols"]
        ),
    ],
    dependencies: [
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.38.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ThreemaProtocols",
            dependencies: [
                "ThreemaEssentials",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        .testTarget(
            name: "ThreemaProtocolsTests",
            dependencies: ["ThreemaProtocols"]
        ),
    ]
)
