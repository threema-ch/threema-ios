// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ThreemaArgon2",
    products: [
        .library(
            name: "ThreemaArgon2",
            targets: ["ThreemaArgon2"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/P-H-C/phc-winner-argon2",
            revision: "f57e61e"
        ),
    ],
    targets: [
        .target(
            name: "ThreemaArgon2",
            dependencies: [
                // This product cannot be renamed, because it isn't Swift only code:
                // https://github.com/apple/swift-package-manager/blob/main/Documentation/ModuleAliasing.md
                .product(name: "argon2", package: "phc-winner-argon2"),
            ]
        ),
        .testTarget(
            name: "ThreemaArgon2Tests",
            dependencies: ["ThreemaArgon2"]
        ),
    ]
)
