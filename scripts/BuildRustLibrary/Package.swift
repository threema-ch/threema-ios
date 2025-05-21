// swift-tools-version: 6.0

// For now this only is a placeholder package to better develop the build script with immediate build errors & tests

import PackageDescription

let package = Package(
    name: "BuildRustLibrary",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "BuildRustLibraryScript"
        ),
        .testTarget(
            name: "BuildRustLibraryScriptTests",
            dependencies: ["BuildRustLibraryScript"],
            resources: [
                .copy("rust-library"),
            ]
        ),
    ]
)
