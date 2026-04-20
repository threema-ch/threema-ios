import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class SafeDataTests: XCTestCase {
    func testEncodeDecode() throws {
        let safeData = SafeData(
            key: Array(BytesUtility.generateRandomBytes(length: 64)!),
            customServer: "https://threema.ch",
            serverUser: "user1",
            serverPassword: "password1",
            server: "https://threema.ch/test",
            maxBackupBytes: 1024,
            retentionDays: 100,
            backupSize: 512,
            backupStartedAt: Date(),
            lastBackup: Date(),
            lastResult: "200",
            lastChecksum: Array(BytesUtility.generateRandomBytes(length: 32)!),
            lastAlertBackupFailed: Date(),
            isTriggered: 0
        )

        let data = try NSKeyedArchiver
            .archivedData(withRootObject: safeData as Any, requiringSecureCoding: true)

        let result = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [SafeData.self, NSArray.self, NSDate.self, NSNumber.self, NSString.self],
                from: data
            ) as? SafeData
        )

        XCTAssertNil(result.key)
        XCTAssertEqual(result.customServer, safeData.customServer)
        XCTAssertNil(result.serverUser)
        XCTAssertNil(result.serverPassword)
        XCTAssertEqual(result.server, safeData.server)
        XCTAssertEqual(result.maxBackupBytes, safeData.maxBackupBytes)
        XCTAssertEqual(result.retentionDays, safeData.retentionDays)
        XCTAssertEqual(result.backupSize, safeData.backupSize)
        XCTAssertEqual(result.backupStartedAt, safeData.backupStartedAt)
        XCTAssertEqual(result.lastBackup, safeData.lastBackup)
        XCTAssertEqual(result.lastResult, safeData.lastResult)
        XCTAssertEqual(result.lastChecksum, safeData.lastChecksum)
        XCTAssertEqual(result.lastAlertBackupFailed, safeData.lastAlertBackupFailed)
        XCTAssertEqual(result.isTriggered, safeData.isTriggered)
    }
}
