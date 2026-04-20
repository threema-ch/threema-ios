// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ThreemaBlake2b",
    products: [
        .library(
            name: "ThreemaBlake2b",
            targets: ["ThreemaBlake2b"]
        ),
    ],
    targets: [
        .target(
            name: "CBlake2"
            // Reference implementation from https://github.com/BLAKE2/BLAKE2/tree/master/ref
            // as of 17.05.2023
        ),
        .target(
            name: "CThreemaBlake2b",
            dependencies: ["CBlake2"]
        ),
        .target(
            name: "ThreemaBlake2b",
            dependencies: ["CBlake2", "CThreemaBlake2b"]
        ),
        .testTarget(
            name: "ThreemaBlake2bTests",
            dependencies: ["ThreemaBlake2b"]
        ),
    ]
)
