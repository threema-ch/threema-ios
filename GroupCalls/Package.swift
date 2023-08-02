// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GroupCalls",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GroupCalls",
            targets: ["GroupCalls"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(path: "../ThreemaProtocols"),
        .package(path: "../ThreemaBlake2b"),
        .package(path: "../ThreemaEssentials"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GroupCalls",
            dependencies: [
                "WebRTC",
                "ThreemaProtocols",
                "ThreemaBlake2b",
                "ThreemaEssentials",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
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
            name: "GroupCallsTests",
            dependencies: ["GroupCalls"]
        ),
        // Importing frameworks that are already used in our existing app targets
        .binaryTarget(name: "WebRTC", path: "../WebRTC.xcframework"),
        
        // To run tests in Xcode the WebRTC framework needs to be signed
        // WARN: The failure will tell you that the module cannot be loaded but not that it is because it wasn't signed.
        //
        // codesign --sign - --force WebRTC.xcframework/ios-arm64_x86_64-simulator/WebRTC.framework/
        // codesign --sign - --force WebRTC.xcframework/ios-arm64/WebRTC.framework/
        // codesign --sign - --force WebRTC.xcframework
    ]
)
