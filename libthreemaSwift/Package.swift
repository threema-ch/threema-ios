// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "libthreemaSwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "libthreemaSwift",
            targets: ["libthreemaSwift"]
        ),
        .library(
            name: "libthreemaSwiftTestHelper",
            targets: ["libthreemaSwiftTestHelper"]
        ),
    ],
    dependencies: [
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.8.5"),
    ],
    targets: [
        .target(
            name: "libthreemaSwift",
            dependencies: [
                "libthreema",
                "ThreemaEssentials",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ]
        ),
        .binaryTarget(
            name: "libthreema",
            path: "./libthreema.xcframework"
        ),
        .target(
            name: "libthreemaSwiftTestHelper",
            dependencies: [
                "libthreemaSwift",
                .product(name: "ThreemaEssentials", package: "ThreemaEssentials"),
            ],
            path: "Tests/Helper"
        ),
        .testTarget(
            name: "libthreemaSwiftTests",
            dependencies: ["libthreemaSwift"]
        ),
    ],
    // The generated code from UniFFI doesn't fully fix all concurrency errors of Swift 6 language mode for now:
    // https://github.com/mozilla/uniffi-rs/issues/2279
    swiftLanguageModes: [.v5]
)
