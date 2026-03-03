// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "FileUtility",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "FileUtility",
            targets: ["FileUtility"]
        ),
        .library(name: "FileUtilityTestHelper", targets: ["FileUtilityTestHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.8.5"),
    ],
    targets: [
        .target(
            name: "FileUtility",
            dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ]
        ),
        .target(
            name: "FileUtilityTestHelper",
            dependencies: ["FileUtility"],
            path: "Tests/Helper"
        ),
        .testTarget(
            name: "FileUtilityTests",
            dependencies: ["FileUtility", "FileUtilityTestHelper"]
        ),
    ],
    swiftLanguageModes: [.v5],
)
