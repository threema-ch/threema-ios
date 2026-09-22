// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ThreemaEssentials",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ThreemaEssentials",
            targets: ["ThreemaEssentials"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.9.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ThreemaEssentials",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            
            swiftSettings: [
                .unsafeFlags([
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
