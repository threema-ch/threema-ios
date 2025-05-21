import Foundation
import Testing
@testable import BuildRustLibraryScript

@Test("Initial build")
func initialBuild() async throws {
    let rustLibraryName = "rust-library"
    
    let baseResourceURL = try #require(Bundle.module.resourceURL)
    let rustLibraryPath = baseResourceURL.appending(path: rustLibraryName)
    
    let (buildDirectory, deleteBuildDirectory) = try FileManager.default.urlForUniqueTemporaryDirectory(
        baseDirectory: "BuildRustLibraryScriptTests"
    )
    let (outDirectory, deleteOutDirectory) = try FileManager.default.urlForUniqueTemporaryDirectory(
        baseDirectory: "BuildRustLibraryScriptTests"
    )
    let outXCFrameworkPath = outDirectory.appendingPathComponent("\(rustLibraryName).xcframework")
    let outSwiftPackagePath = outDirectory.appendingPathComponent("\(rustLibraryName).swift")
    
    let targets = [
        "aarch64-apple-darwin",
    ]
    
    try BuildRustLibraryScript.run(
        libraryName: rustLibraryName,
        libraryPath: rustLibraryPath,
        buildPath: buildDirectory,
        frameworkOutputFilePath: outXCFrameworkPath,
        swiftFileOutputFilePath: outSwiftPackagePath,
        targets: targets,
        force: false,
        verbose: true
    )
    
    let buildDirectoryContent = try FileManager.default.contentsOfDirectory(
        at: buildDirectory,
        includingPropertiesForKeys: nil
    )
    // Target & UnFFI bridging stuff -> If this fails adjust it to the new value
    #expect(buildDirectoryContent.count == 2)
    
    let outputDirectoryContent = try FileManager.default.contentsOfDirectory(
        at: outDirectory,
        includingPropertiesForKeys: nil
    )
    #expect(outputDirectoryContent.count == 2)
    #expect(outputDirectoryContent.contains(
        where: { $0.lastPathComponent == "\(rustLibraryName).xcframework" }
    ) == true)
    #expect(outputDirectoryContent.contains(where: { $0.lastPathComponent == "\(rustLibraryName).swift" }) == true)
    
    try deleteBuildDirectory()
    try deleteOutDirectory()
}

@Test("Parsing of all required commands")
func requiredCommandsParsing() async throws {
    let expectedLibraryName = "rust-library"
    let expectedLibraryPath = URL(filePath: "library-path")
    let expectedFrameworkOutputFilePath = URL(filePath: "framework-output-path/rust_library.xcframework")
    let expectedSwiftOutputFilePath = URL(filePath: "swift-file-output-path/rust_library.swift")
    let expectedTargets = [
        "aarch64-apple-darwin",
        "aarch64-apple-ios",
    ]
    
    let arguments = [
        "script-name",
        expectedLibraryName,
        "--library-path",
        expectedLibraryPath.path,
        "--framework-out-file-path",
        expectedFrameworkOutputFilePath.path,
        "--swift-out-file-path",
        expectedSwiftOutputFilePath.path,
        "--targets",
    ] + expectedTargets
    
    let (
        actualLibraryName,
        actualLibraryPath,
        actualBuildPath,
        actualFrameworkOutputFilePath,
        actualSwiftFileOutputFilePath,
        actualTargets,
        actualForce,
        actualVerbose
    ) = try BuildRustLibraryScript.parse(arguments: arguments)
    
    #expect(actualLibraryName == expectedLibraryName)
    #expect(actualLibraryPath.absoluteURL == expectedLibraryPath.absoluteURL)
    #expect(actualBuildPath == nil)
    #expect(actualFrameworkOutputFilePath.absoluteURL == expectedFrameworkOutputFilePath.absoluteURL)
    #expect(actualSwiftFileOutputFilePath.absoluteURL == expectedSwiftOutputFilePath.absoluteURL)
    #expect(actualTargets == expectedTargets)
    #expect(actualForce == false)
    #expect(actualVerbose == false)
}

@Test("Parsing of optional flags")
func optionalFlagsParsing() async throws {
    let expectedBuildPath = URL(filePath: "build-path")
    let expectedVerbose = true
    let expectedForce = true
    
    let arguments = [
        "script-name",
        "rust-library",
        "--library-path",
        "library-path",
        "--build-path",
        expectedBuildPath.path,
        "--framework-out-file-path",
        "framework-output-path/rust_library.xcframework",
        "--swift-out-file-path",
        "swift-file-output-path/rust_library.swift",
        "--targets",
        "aarch64-apple-darwin",
        "--verbose",
        "--force",
    ]
    
    let (
        _,
        _,
        actualBuildPath,
        _,
        _,
        _,
        actualForce,
        actualVerbose
    ) = try BuildRustLibraryScript.parse(arguments: arguments)
    
    #expect(actualBuildPath?.absoluteURL == expectedBuildPath.absoluteURL)
    #expect(actualForce == expectedForce)
    #expect(actualVerbose == expectedVerbose)
}

extension FileManager {
    /// Creates a temporary directory with a unique name and returns its URL.
    ///
    /// - Returns: A tuple of the directory's URL and a delete function.
    ///   Call the function to delete the directory after you're done with it.
    ///
    /// - Note: You should not rely on the existence of the temporary directory
    ///   after the app is exited.
    fileprivate func urlForUniqueTemporaryDirectory(baseDirectory: String) throws
        -> (url: URL, deleteDirectory: () throws -> Void) {
        let baseDirectoryName = temporaryDirectory.appendingPathComponent(baseDirectory, isDirectory: true)
        
        if !fileExists(atPath: baseDirectoryName.path) {
            try createDirectory(at: baseDirectoryName, withIntermediateDirectories: false)
        }

        let basename = UUID().uuidString
        
        var counter = 0
        var createdSubdirectory: URL?
        repeat {
            do {
                let subdirectoryName = counter == 0 ? basename : "\(basename)-\(counter)"
                let subdirectory = baseDirectoryName.appendingPathComponent(subdirectoryName, isDirectory: true)
                try createDirectory(at: subdirectory, withIntermediateDirectories: false)
                createdSubdirectory = subdirectory
            }
            catch CocoaError.fileWriteFileExists {
                // Catch file exists error and try again with another name.
                // Other errors propagate to the caller.
                counter += 1
            }
        }
        while createdSubdirectory == nil

        let directory = createdSubdirectory!
        let deleteDirectory: () throws -> Void = {
            try self.removeItem(at: directory)
        }
        return (directory, deleteDirectory)
    }
}
