#!/usr/bin/env swift

// See README for information about this script

import Foundation

let arguments = CommandLine.arguments // ProcessInfo().arguments gives you all process arguments

guard let scriptFilePath = arguments.first else {
    print(usageString(scriptFilePath: nil, with: nil))
    exit(-1)
}

do {
    let (
        libraryName,
        libraryPath,
        buildPath,
        frameworkOutputFilePath,
        swiftFileOutputFilePath,
        targets,
        force,
        verbose
    ) = try parse(
        arguments: arguments
    )
    
    if verbose {
        print(libraryName)
        print(libraryPath)
        print(buildPath?.absoluteString ?? "no build path")
        print(frameworkOutputFilePath)
        print(swiftFileOutputFilePath)
    }
    
    try run(
        libraryName: libraryName,
        libraryPath: libraryPath,
        buildPath: buildPath,
        frameworkOutputFilePath: frameworkOutputFilePath,
        swiftFileOutputFilePath: swiftFileOutputFilePath,
        targets: targets,
        force: force,
        verbose: verbose
    )
}
catch {
    print(usageString(scriptFilePath: scriptFilePath, with: error as? BuildRustError))
    exit(-1)
}

// MARK: - Helper functions

// MARK: Parsing input

private enum Option: String, CaseIterable {
    case libraryPath = "--library-path"
    case buildPath = "--build-path"
    case frameworkOutputFilePath = "--framework-out-file-path"
    case swiftOutputFilePath = "--swift-out-file-path"
    case targets = "--targets"
    case force = "--force"
    case verbose = "--verbose"
    
    var help: String {
        switch self {
        case .libraryPath:
            "Path to Rust library"
        case .buildPath:
            "Path where build artifacts are stored. If not provided default Rust paths are used at the library path (defaults are imitated based on cargo behavior in early of 2025)"
        case .frameworkOutputFilePath:
            "Path of XCFramework including its name"
        case .swiftOutputFilePath:
            "Path of Swift file with bindings including its name"
        case .targets:
            "One or more Rust targets (e.g. aarch64-apple-darwin)"
        case .force:
            "Force recreation of bindings, XCFramework and Swift file, even if Rust library hasn't changed"
        case .verbose:
            "Show more output"
        }
    }
}

private func usageString(scriptFilePath: String?, with error: BuildRustError?) -> String {
    let options = Option.allCases.map { option in
        "  \(option.rawValue): \(option.help)"
    }.joined(separator: "\n")
    
    let resolvedScriptFilePath = scriptFilePath ?? "./BuildRustLibrary/Sources/BuildRustLibraryScript/main.swift"
    
    let usage = """
        USAGE: \(resolvedScriptFilePath) <library-name> \(Option.libraryPath.rawValue) <library-path> \
        [\(Option.buildPath.rawValue) <build-path>] \
        \(Option.frameworkOutputFilePath.rawValue) <framework-output-path> \
        \(Option.swiftOutputFilePath.rawValue) <swift-file-output-path> \
        \(Option.targets.rawValue) <one-or-more-rust-targets> \
        [\(Option.force.rawValue) \(Option.verbose.rawValue)]

        
        ARGUMENTS:
        \(options)
        """
    
    if let error {
        return "\n⚠️ \(error.description)\n\n\(usage)\n"
    }
    else {
        return usage
    }
}

enum BuildRustError: Error {
    case parsingFailure
    case missingArgument
    case unknownArgument
    case shellExecutionFailure
    
    var description: String {
        switch self {
        case .parsingFailure:
            "Parsing failure"
        case .missingArgument:
            "Missing argument"
        case .unknownArgument:
            "Unknown argument"
        case .shellExecutionFailure:
            "Shell command returned a non-zero value"
        }
    }
}

func parse(arguments: [String]) throws -> (
    libraryName: String,
    libraryPath: URL,
    buildPath: URL?,
    frameworkOutputFilePath: URL,
    swiftFileOutputFilePath: URL,
    targets: [String],
    force: Bool,
    verbose: Bool
) {
    guard arguments.count >= 2 else {
        throw BuildRustError.missingArgument
    }
    
    var arguments = arguments
    
    // Remove script file path
    _ = arguments.removeFirst()
    
    let libraryName = arguments.removeFirst()
    
    var libraryPath: URL?
    var buildPath: URL?
    var frameworkOutputPath: URL?
    var swiftFileOutputPath: URL?
    var targets = [String]()
    var force = false
    var verbose = false
    
    func parsePathArgument(_ arguments: inout [String]) throws -> URL {
        guard !arguments.isEmpty else {
            throw BuildRustError.parsingFailure
        }
        
        return URL(filePath: arguments.removeFirst())
    }
 
    while !arguments.isEmpty {
        guard let option = Option(rawValue: arguments.removeFirst()) else {
            throw BuildRustError.unknownArgument
        }
        
        switch option {
        case .libraryPath:
            libraryPath = try parsePathArgument(&arguments)
        case .buildPath:
            buildPath = try parsePathArgument(&arguments)
        case .frameworkOutputFilePath:
            frameworkOutputPath = try parsePathArgument(&arguments)
        case .swiftOutputFilePath:
            swiftFileOutputPath = try parsePathArgument(&arguments)
        case .targets:
            targetsLoop: while !arguments.isEmpty {
                guard !arguments[0].hasPrefix("--") else {
                    break targetsLoop
                }
                
                targets.append(arguments.removeFirst())
            }
        case .force:
            force = true
        case .verbose:
            verbose = true
        }
    }
    
    guard let libraryPath, let frameworkOutputPath, let swiftFileOutputPath, !targets.isEmpty else {
        throw BuildRustError.missingArgument
    }
    
    return (
        libraryName,
        libraryPath,
        buildPath,
        frameworkOutputPath,
        swiftFileOutputPath,
        targets,
        force,
        verbose
    )
}

// MARK: Generate library & create binding

func run(
    libraryName: String,
    libraryPath: URL,
    buildPath: URL?,
    frameworkOutputFilePath: URL,
    swiftFileOutputFilePath: URL,
    targets: [String],
    force: Bool,
    verbose: Bool
) throws {
    
    // Defaults as of early 2025
    let defaultRustTargetPath = "target"
    let defaultUniFFIPath = "build/swift"
    
    let outputLibraryName = libraryName.replacingOccurrences(of: "-", with: "_")
    let rustTargetBuildPath: URL = (buildPath ?? libraryPath).appending(path: defaultRustTargetPath)
    let uniFFIBuildPath: URL = (buildPath ?? libraryPath).appending(path: defaultUniFFIPath)

    let startDate = Date.now
    
    // Build targets...
    
    let targetFlags = targets.map {
        "--target=\($0)"
    }

    let buildTargetsCommand = """
        cargo build -F uniffi -p \(libraryName) --release \
        --target-dir \(rustTargetBuildPath.path) \
        \(targetFlags.joined(separator: " "))
        """
    
    try runInZSH(
        command: buildTargetsCommand,
        in: libraryPath,
        verbose: verbose
    )
    
    // Check if any of the library files actually changed... Stop otherwise.
    
    let libraryPaths = targets.map {
        "\(rustTargetBuildPath.path)/\($0)/release/lib\(outputLibraryName).a"
    }
    
    if !force {
        let libraryURLs: [URL] = libraryPaths.map { URL(filePath: $0) }
        guard try checkForModifications(of: libraryURLs, after: startDate, verbose: verbose) else {
            print("\n❎ Nothing changed. Done")
            return
        }
    }
    
    // Generate UniFFI bindings...
    
    let generateUniFFIBindingsCommand = """
        cargo run --target-dir \(rustTargetBuildPath.path) -p uniffi-bindgen generate \
        --library \(libraryPaths.first!) \
        --language swift --out-dir \(uniFFIBuildPath.path) \
        --no-format
        """
    
    try runInZSH(
        command: generateUniFFIBindingsCommand,
        in: libraryPath,
        verbose: verbose
    )
        
    // Move Swift file
        
    if FileManager.default.fileExists(atPath: swiftFileOutputFilePath.path) {
        try FileManager.default.removeItem(at: swiftFileOutputFilePath)
    }
    else {
        // There might be some intermediary paths that are missing
        try FileManager.default.createDirectory(
            // Assuming the last component is the Swift file name
            at: swiftFileOutputFilePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
    
    // This will throw an error if the file existed before
    try FileManager.default.moveItem(
        at: uniFFIBuildPath.appending(path: "\(outputLibraryName).swift"),
        to: swiftFileOutputFilePath
    )
    
    // Generate XCFramework
    
    // Fix name of module map. For an XCFramework it needs to be called `module.modulemap`
    
    let initialModuleMap = uniFFIBuildPath.appending(path: "\(outputLibraryName)FFI.modulemap")
    let newModuleMap = uniFFIBuildPath.appending(path: "module.modulemap")
    
    if FileManager.default.fileExists(atPath: initialModuleMap.path) {
        if FileManager.default.fileExists(atPath: newModuleMap.path) {
            try FileManager.default.removeItem(at: newModuleMap)
        }
        
        try FileManager.default.moveItem(at: initialModuleMap, to: newModuleMap)
    }
        
    // Remove existing XCFramework if needed
    if FileManager.default.fileExists(atPath: frameworkOutputFilePath.path) {
        try FileManager.default.removeItem(at: frameworkOutputFilePath)
    }
        
    // We decided to use a static library because that is recommended by the UniFFI documentation
    // (https://mozilla.github.io/uniffi-rs/0.28/tutorial/Prerequisites.html) & in our short test the dynamic library
    // was not included in a binary uploaded to App Store Connect leading to a crash on launch
    
    let libraryTargetFlags = libraryPaths.map {
        "-library \($0) -headers \(uniFFIBuildPath.path)"
    }
    
    let createXCFrameworkCommand = """
        xcodebuild \
        -create-xcframework \(libraryTargetFlags.joined(separator: " ")) \
        -output \(frameworkOutputFilePath.path)
        """
    
    try runInZSH(command: createXCFrameworkCommand, in: libraryPath, verbose: verbose)
    
    print("\n✅ \(libraryName) bindings successfully created!")
}

private func runInZSH(command: String, in directory: URL, verbose: Bool) throws {
    if verbose {
        print(command)
        print(directory)
    }
    
    let process = Process()
    // We use zsh such that we can set a PATH
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [
        "-c", command,
    ]
    process.currentDirectoryURL = directory
    process.environment = [
        "PATH": "$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
    ]
    
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        if verbose {
            print("Exit status \(process.terminationStatus)")
        }
        throw BuildRustError.shellExecutionFailure
    }
    
    if verbose {
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        
        print("Shell output: \(output)")
    }
}

private func checkForModifications(of files: [URL], after lastCheck: Date, verbose: Bool) throws -> Bool {
    for file in files {
        guard FileManager.default.fileExists(atPath: file.path) else {
            if verbose {
                print("\(file) doesn't exist")
            }
            continue
        }
        
        if verbose {
            print("Check \(file)")
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let modificationDate = attributes[.modificationDate] as? Date else {
            if verbose {
                print("No modification date for \(file)")
            }
            continue
        }
        
        if modificationDate > lastCheck {
            if verbose {
                print("\(file.lastPathComponent) has been modified (\(modificationDate)) after \(lastCheck)")
            }
            return true
        }
    }
    
    return false
}
