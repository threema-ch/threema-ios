// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThreemaEssentials",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ThreemaEssentials",
            targets: ["ThreemaEssentials"]
        ),
    ],
    dependencies: [
        .package(path: "../ThreemaProtocols"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ThreemaEssentials",
            dependencies: [
                "ThreemaProtocols",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend",
                    "-warn-concurrency",
                    "-Xfrontend",
                    "-enable-actor-data-race-checks",
                    "-Xfrontend",
                    "-warn-long-function-bodies=100",
                    "-Xfrontend",
                    "-warn-long-expression-type-checking=100",
                ]),
            ]
        
        ),
        .testTarget(
            name: "ThreemaEssentialsTests",
            dependencies: ["ThreemaEssentials"]
        ),
    ]
)
