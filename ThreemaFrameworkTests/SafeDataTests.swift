//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
