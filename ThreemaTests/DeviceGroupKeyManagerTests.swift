import KeychainTestHelper
import ThreemaEssentials
import XCTest
@testable import Threema

/// This tests works only in app context, because of storing key in keychain.
final class DeviceGroupKeyManagerTests: XCTestCase {

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
