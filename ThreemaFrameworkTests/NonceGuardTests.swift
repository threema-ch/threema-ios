//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class NonceGuardTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        ddLoggerMock.logMessages.removeAll()
    }

    func testIsProcessed() throws {
        let nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))!
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        entityManager.performSyncBlockAndSafe {
            entityManager.entityCreator.nonce(with: nonce)
        }

        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = nonce

        let nonceGuard = NonceGuard(entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
    }

    func testIsProcessedNoNonceStored() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let nonceGuard = NonceGuard(entityManager: EntityManager(databaseContext: dbMainCnx))
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testIsProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(entityManager: EntityManager(databaseContext: dbMainCnx))
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
        XCTAssertTrue(ddLoggerMock.exists(message: "Message nonce is nil or empty"))
    }

    func testIsProcessedReflected() throws {
        let nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))!
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        entityManager.performSyncBlockAndSafe {
            entityManager.entityCreator.nonce(with: nonce)
        }

        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = nonce

        let nonceGuard = NonceGuard(entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
    }

    func testIsProcessedNoNonceStoredReflected() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let nonceGuard = NonceGuard(entityManager: EntityManager(databaseContext: dbMainCnx))
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testProcessed() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let entityManager = EntityManager(databaseContext: dbMainCnx)
        let nonceGuard = NonceGuard(entityManager: entityManager)

        let expect = expectation(description: "nonce guard processed")

        try nonceGuard.processed(message: expectedIncomingMessage)
            .done { _ in
                expect.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [expect], timeout: 3)

        XCTAssertTrue(entityManager.entityFetcher.isNonceAlreadyInDB(nonce: expectedIncomingMessage.nonce))
    }

    func testProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(entityManager: EntityManager(databaseContext: dbMainCnx))

        XCTAssertThrowsError(
            try nonceGuard.processed(message: expectedIncomingMessage),
            "Message nonce is nil"
        ) { error in
            XCTAssertEqual(error as? NonceGuard.NonceGuardError, .messageNonceIsNil)
        }
    }

    func testProcessedReflected() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let entityManager = EntityManager(databaseContext: dbMainCnx)
        let nonceGuard = NonceGuard(entityManager: entityManager)

        let expect = expectation(description: "nonce guard processed")

        try nonceGuard.processed(message: expectedIncomingMessage)
            .done { _ in
                expect.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [expect], timeout: 3)

        XCTAssertTrue(entityManager.entityFetcher.isNonceAlreadyInDB(nonce: expectedIncomingMessage.nonce))
    }
}
