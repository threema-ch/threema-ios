// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DataBackup",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "DataBackup",
            targets: ["DataBackup"],
        ),
        .library(name: "DataBackupTestHelper", targets: ["DataBackupTestHelper"]),
    ],
    dependencies: [
        .package(path: "../FileUtility"),
        .package(path: "../Keychain"),
        .package(path: "../libthreemaSwift"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", exact: "3.9.1"),
    ],
    targets: [
        .target(
            name: "DataBackup",
            dependencies: [
                "FileUtility",
                "Keychain",
                "libthreemaSwift",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
        ),
        .target(
            name: "DataBackupTestHelper",
            dependencies: [
                "DataBackup",
                .product(name: "libthreemaSwift", package: "libthreemaSwift"),
                .product(name: "libthreemaSwiftTestHelper", package: "libthreemaSwift"),
            ],
            path: "Tests/Helper"
        ),
        .testTarget(
            name: "DataBackupTests",
            dependencies: [
                "DataBackup",
                "DataBackupTestHelper",
                .product(name: "FileUtility", package: "FileUtility"),
                .product(name: "FileUtilityTestHelper", package: "FileUtility"),
                .product(name: "Keychain", package: "Keychain"),
                .product(name: "KeychainTestHelper", package: "Keychain"),
                .product(name: "libthreemaSwift", package: "libthreemaSwift"),
                .product(name: "libthreemaSwiftTestHelper", package: "libthreemaSwift"),
            ],
        ),
    ]
)
