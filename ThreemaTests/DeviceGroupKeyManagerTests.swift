//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import KeychainTestHelper
import ThreemaEssentials
import XCTest
@testable import Threema

/// This tests works only in app context, because of storing key in keychain.
class DeviceGroupKeyManagerTests: XCTestCase {

    func testDgk() throws {
        let keychainManagerMock = KeychainManagerMock()

        let deviceGroupKeyManager = DeviceGroupKeyManager(keychainManager: keychainManagerMock)

        let key = deviceGroupKeyManager.create()
        let result = deviceGroupKeyManager.dgk

        XCTAssertNotNil(result)
        XCTAssertEqual(key, result)
        XCTAssertEqual(result?.count, ThreemaProtocol.deviceGroupKeyLength)
        XCTAssertEqual(1, keychainManagerMock.loadMultiDeviceGroupKeyCalls)
        XCTAssertEqual(1, keychainManagerMock.storeMultiDeviceGroupKeyCalls.count)
    }

    func testStoreAndLoad() throws {
        let keychainManagerMock = KeychainManagerMock()

        let expectedDgk = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceGroupKeyLength)!

        let deviceGroupKeyManager = DeviceGroupKeyManager(keychainManager: keychainManagerMock)
        let stored = deviceGroupKeyManager.store(dgk: expectedDgk)

        XCTAssertTrue(stored)

        let result = deviceGroupKeyManager.load()

        XCTAssertNotNil(result)
        XCTAssertEqual(result, expectedDgk)
        XCTAssertEqual(1, keychainManagerMock.loadMultiDeviceGroupKeyCalls)
        XCTAssertEqual(1, keychainManagerMock.storeMultiDeviceGroupKeyCalls.count)
    }
}
