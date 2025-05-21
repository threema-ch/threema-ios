// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "libthreemaSwift",
    products: [
        .library(
            name: "libthreemaSwift",
            targets: ["libthreemaSwift"]
        ),
    ],
    targets: [
        .target(
            name: "libthreemaSwift",
            dependencies: ["libthreema"]
        ),
        .binaryTarget(
            name: "libthreema",
            path: "./libthreema.xcframework"
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
