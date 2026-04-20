import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class NonceGuardTests: XCTestCase {
    private let myIdentityStore = MyIdentityStoreMock()
    
    private var entityManager: EntityManager!
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let testDatabase = TestDatabase()

        entityManager = testDatabase.entityManager
        dbPreparer = testDatabase.preparer

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        ddLoggerMock.logMessages.removeAll()
    }

    func testIsProcessed() throws {
        let nonce = BytesUtility.generateMessageNonce()
        let hashedNonce = NonceHasher.hashedNonce(nonce, myIdentity: myIdentityStore.identity)
        entityManager.performAndWaitSave {
            _ = self.entityManager.entityCreator.nonceEntity(for: hashedNonce!)
        }

        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = nonce

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
    }

    func testIsProcessedNoNonceStored() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateMessageNonce()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testIsProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "Nonce of message \(expectedIncomingMessage.loggingDescription) is empty")
        )
    }

    func testIsProcessedReflected() throws {
        let nonce = BytesUtility.generateMessageNonce()
        let hashedNonce = NonceHasher.hashedNonce(nonce, myIdentity: myIdentityStore.identity)
        entityManager.performAndWaitSave {
            _ = self.entityManager.entityCreator.nonceEntity(for: hashedNonce!)
        }

        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = nonce

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertTrue(result)
    }

    func testIsProcessedNoNonceStoredReflected() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateMessageNonce()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        let result = nonceGuard.isProcessed(message: expectedIncomingMessage)

        XCTAssertFalse(result)
    }

    func testProcessed() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateMessageNonce()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        try nonceGuard.processed(message: expectedIncomingMessage)
        let hashedNonce = NonceHasher.hashedNonce(expectedIncomingMessage.nonce, myIdentity: myIdentityStore.identity)!
       
        XCTAssertTrue(entityManager.entityFetcher.isNonceEntityAlreadyInDB(
            hashedNonce
        ))
    }

    func testProcessedNonceIsNil() throws {
        let expectedIncomingMessage = BoxTextMessage()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)

        XCTAssertThrowsError(
            try nonceGuard.processed(message: expectedIncomingMessage),
            "Message nonce is nil"
        ) { error in
            if case NonceGuard.NonceGuardError.messageNonceIsNil(
                message: "Can't store nonce of message \(expectedIncomingMessage.loggingDescription)"
            ) = error { }
            else {
                XCTFail("Wrong error message")
            }
        }
    }

    func testProcessedReflected() throws {
        let expectedIncomingMessage = BoxTextMessage()
        expectedIncomingMessage.nonce = BytesUtility.generateMessageNonce()

        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        try nonceGuard.processed(message: expectedIncomingMessage)
        let hashedNonce = NonceHasher.hashedNonce(expectedIncomingMessage.nonce, myIdentity: myIdentityStore.identity)!
        
        XCTAssertTrue(entityManager.entityFetcher.isNonceEntityAlreadyInDB(
            hashedNonce
        ))
    }
    
    func testDoNotStoreSameNonceTwice() throws {
        let nonce = BytesUtility.generateMessageNonce()
        
        let nonceGuard = NonceGuard(myIdentityStore: myIdentityStore, entityManager: entityManager)
        try nonceGuard.processed(nonces: [nonce, nonce])

        let hashedNonce = NonceHasher.hashedNonce(nonce, myIdentity: myIdentityStore.identity)
        let matchedDBNonces = entityManager.entityFetcher.nonceEntities()?.filter {
            $0.nonce == hashedNonce
        }
        
        XCTAssertTrue(entityManager.entityFetcher.isNonceEntityAlreadyInDB(
            hashedNonce!
        ))
        XCTAssertEqual(1, matchedDBNonces?.count)
    }
}
