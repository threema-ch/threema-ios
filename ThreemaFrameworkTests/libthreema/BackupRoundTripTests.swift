import Foundation
import Testing
@testable import ThreemaFramework

/// Step 2 of the backup round trip job: for each fixture, the app restores the reference backup the test driver
/// created, then backs the restored data up again. The test driver compares both backups afterwards, so this only
/// fails if the app throws.
///
/// Runs only in that roundtrip job, which hands the fixtures over in environment variables.
/// xcodebuild passes each `TEST_RUNNER_<name>` variable on to the tests as `<name>`. Each fixture is a test
/// case of its own, so the test is built once for all of them. The cases run one after the other, each on an empty
/// device.
///
/// Only in the simulator: the backups are in a directory on the Mac, and a device has no access to it.
@MainActor
@Suite("Backup round trip")
struct BackupRoundTripTests {

    @Test(
        .enabled(if: RoundTripVariable.isRoundTripJob, "Only runs in the backup round trip job")
    )
    func fixturesAreSet() throws {
        // Without fixtures, `restoreAndBackUpAgain` has no test cases and passes without doing anything
        try #require(
            !RoundTripVariable.fixtureNames.isEmpty,
            "Set TEST_RUNNER_\(RoundTripVariable.fixtures.rawValue) for xcodebuild, like fixture0001,fixture0002"
        )
    }

    @Test(
        .enabled(if: RoundTripVariable.isRoundTripJob, "Only runs in the backup round trip job"),
        .serialized,
        arguments: RoundTripVariable.fixtureNames
    )
    func restoreAndBackUpAgain(fixture: String) async throws {
        // On a device this would only fail later, on a reference backup it cannot find
        try #require(
            Self.runsInSimulator,
            "Only runs in the simulator: a device cannot reach the backups in the directory on the Mac"
        )

        let directory = try URL(filePath: RoundTripVariable.directory.require(), directoryHint: .isDirectory)
        let password = try RoundTripVariable.password.require()

        // The same names as the test driver uses, see `src/files.rs` in libthreema-test-driver
        let referenceURL = directory.appending(path: "\(fixture).reference.backup")
        let roundTripURL = directory.appending(path: "\(fixture).roundtrip.backup")

        let environment = BackupTestEnvironment()

        try await environment.restore(from: referenceURL, password: password)
        try await environment.backup(to: roundTripURL, password: password)
    }

    // MARK: - Private properties

    /// Whether the tests run in the simulator, which shares the file system of the Mac the job keeps the backups on.
    private static var runsInSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
}

// MARK: - RoundTripVariable

/// The environment variables the backup round trip job sets.
private enum RoundTripVariable: String {
    /// Directory with the reference backup of each fixture, `<fixture>.reference.backup`, that the test driver
    /// created. The new backup of each fixture is written next to it, as `<fixture>.roundtrip.backup`, for the test
    /// driver to compare. An existing file is replaced.
    case directory = "BACKUP_ROUNDTRIP_DIRECTORY"

    /// Names of the fixtures to round trip, separated by commas.
    case fixtures = "BACKUP_ROUNDTRIP_FIXTURES"

    /// Password of the reference backups. The new backups are encrypted with it as well.
    case password = "BACKUP_ROUNDTRIP_PASSWORD"

    /// Whether the tests run in the round trip job, which always sets the directory.
    static var isRoundTripJob: Bool {
        directory.value != nil
    }

    /// The fixtures to round trip, one test case each. None outside the round trip job.
    static var fixtureNames: [String] {
        fixtures.value?.split(separator: ",").map { String($0) } ?? []
    }

    var value: String? {
        ProcessInfo.processInfo.environment[rawValue]
    }

    /// The value, failing the test if the job did not set it.
    func require() throws -> String {
        try #require(value, "Set TEST_RUNNER_\(rawValue) for xcodebuild")
    }
}
