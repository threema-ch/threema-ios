//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
@testable import Threema

/// This tests works only in app context, because of storing key in keychain.
class DeviceGroupKeyManagerTests: XCTestCase {

    func testDgk() throws {
        let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: MyIdentityStoreMock())

        let key = deviceGroupKeyManager.create()
        let result = deviceGroupKeyManager.dgk

        XCTAssertNotNil(result)
        XCTAssertEqual(key, result)
        XCTAssertEqual(result?.count, Int(kDeviceGroupKeyLen))
    }

    func testStoreAndLoad() throws {
        let expectedDgk = BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!

        let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: MyIdentityStoreMock())
        let stored = deviceGroupKeyManager.store(dgk: expectedDgk)

        XCTAssertTrue(stored)

        let result = deviceGroupKeyManager.load()

        XCTAssertNotNil(result)
        XCTAssertEqual(result, expectedDgk)
    }
}
