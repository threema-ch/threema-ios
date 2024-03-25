//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
    private var entityManager: EntityManager!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()

        entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: mainCnx, backgroundContext: nil))
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
        entityManager.performAndWaitSave {
            _ = self.entityManager.entityCreator.nonce(with: nonce)
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

        let nonceGuard = NonceGuard(entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testIsProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "Nonce of message \(expectedIncomingMessage.loggingDescription) is empty")
        )
    }

    func testIsProcessedReflected() throws {
        let nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))!
        entityManager.performAndWaitSave {
            _ = self.entityManager.entityCreator.nonce(with: nonce)
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

        let nonceGuard = NonceGuard(entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testProcessed() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let nonceGuard = NonceGuard(entityManager: entityManager)
        try nonceGuard.processed(message: expectedIncomingMessage)

        XCTAssertTrue(entityManager.entityFetcher.isNonceAlreadyInDB(nonce: expectedIncomingMessage.nonce))
    }

    func testProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(entityManager: entityManager)

        XCTAssertThrowsError(
            try nonceGuard.processed(message: expectedIncomingMessage),
            "Message nonce is nil"
        ) { error in
            if case NonceGuard.NonceGuardError
                .messageNonceIsNil(
                    message: "Can't store nonce of message \(expectedIncomingMessage.loggingDescription)"
                ) = error { }
            else {
                XCTFail("Wrong error message")
            }
        }
    }

    func testProcessedReflected() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoNonceSize))

        let nonceGuard = NonceGuard(entityManager: entityManager)
        try nonceGuard.processed(message: expectedIncomingMessage)

        XCTAssertTrue(entityManager.entityFetcher.isNonceAlreadyInDB(nonce: expectedIncomingMessage.nonce))
    }
    
    func testDoNotStoreSameNonceTwice() throws {
        let nonce = MockData.generateMessageNonce()
        
        let nonceGuard = NonceGuard(entityManager: entityManager)
        nonceGuard.processed(nonces: [nonce, nonce])

        let matchedDBNonces = entityManager.entityFetcher.allNonces()?.filter {
            $0.nonce == nonce
        }
        
        XCTAssertTrue(entityManager.entityFetcher.isNonceAlreadyInDB(nonce: nonce))
        XCTAssertEqual(1, matchedDBNonces?.count)
    }
}
