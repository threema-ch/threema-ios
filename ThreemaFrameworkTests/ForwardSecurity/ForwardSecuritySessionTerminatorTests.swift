import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class ForwardSecuritySessionTerminatorTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var databasePreparer: TestDatabasePreparer!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testTerminateAllSessionsWithMultipleToTerminate() throws {
        let sessionStore = InMemoryDHSessionStore()
        let messageSenderMock = MessageSenderMock()
        let entityManager = testDatabase.entityManager
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManager,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: terminateIdentity.rawValue
        )
        
        let terminateSession1 = DHSession(
            peerIdentity: terminateContact.identity,
            peerPublicKey: terminateContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: terminateSession1)
        let terminateSession2 = DHSession(
            peerIdentity: terminateContact.identity,
            peerPublicKey: terminateContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: terminateSession2)
        XCTAssertEqual(2, sessionStore.dhSessionList.count)
        
        // Create identity and sessions to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: keepIdentity.rawValue
        )
        
        let keepSession1 = DHSession(
            peerIdentity: keepContact.identity,
            peerPublicKey: keepContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: keepSession1)
        
        XCTAssertEqual(3, sessionStore.dhSessionList.count)

        // Run
        
        let actuallyDeletedAnySessions = try fsSessionTerminator.terminateAllSessions(
            with: terminateContact.identity,
            cause: .unknownSession
        )
        
        // Validate
        
        // Some sessions should be deleted
        XCTAssertTrue(actuallyDeletedAnySessions)
        // All sessions from `terminateContact` should be deleted
        XCTAssertEqual(1, sessionStore.dhSessionList.count)
        // A terminate message for all `terminateContact` sessions should be scheduled
        XCTAssertEqual(2, messageSenderMock.sentAbstractMessagesQueue.count)
    }
    
    func testTerminateAllSessions() throws {
        let sessionStore = InMemoryDHSessionStore()
        let messageSenderMock = MessageSenderMock()
        let entityManager = testDatabase.entityManager
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManager,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: terminateIdentity.rawValue
        )
        
        let terminateSession1 = DHSession(
            peerIdentity: terminateContact.identity,
            peerPublicKey: terminateContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: terminateSession1)
        XCTAssertEqual(1, sessionStore.dhSessionList.count)
        
        // Run
        
        let actuallyDeletedAnySessions = try fsSessionTerminator.terminateAllSessions(
            with: terminateContact.identity,
            cause: .reset
        )
        
        // Validate
        
        // Some sessions should be deleted
        XCTAssertTrue(actuallyDeletedAnySessions)
        // All sessions from `terminateContact` should be deleted
        XCTAssertEqual(0, sessionStore.dhSessionList.count)
        // A terminate message for the `terminateContact` session should be scheduled
        XCTAssertEqual(1, messageSenderMock.sentAbstractMessagesQueue.count)
    }
    
    func testTerminateWithNoSessionToTerminate() throws {
        let sessionStore = InMemoryDHSessionStore()
        let messageSenderMock = MessageSenderMock()
        let entityManager = testDatabase.entityManager
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManager,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity to be terminated with no existing session
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: terminateIdentity.rawValue
        )
        
        // Create identity and sessions to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: keepIdentity.rawValue
        )
        
        let keepSession1 = DHSession(
            peerIdentity: keepContact.identity,
            peerPublicKey: keepContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: keepSession1)
        
        XCTAssertEqual(1, sessionStore.dhSessionList.count)

        // Run
        
        let actuallyDeletedAnySessions = try fsSessionTerminator.terminateAllSessions(
            with: terminateContact.identity,
            cause: .unknownSession
        )
        
        // Validate
        
        // No sessions should be deleted
        XCTAssertFalse(actuallyDeletedAnySessions)
        // All sessions should still exist
        XCTAssertEqual(1, sessionStore.dhSessionList.count)
        // No terminate message should be scheduled
        XCTAssertEqual(0, messageSenderMock.sentAbstractMessagesQueue.count)
    }
    
    func testDeleteAllSessionsWithMultipleToDelete() throws {
        let sessionStore = InMemoryDHSessionStore()
        let entityManager = testDatabase.entityManager
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManager
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be deleted
        
        let deleteIdentity = ThreemaIdentity("AAAAAAAA")
        let deleteContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: deleteIdentity.rawValue
        )
        
        let deleteSession1 = DHSession(
            peerIdentity: deleteContact.identity,
            peerPublicKey: deleteContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: deleteSession1)
        let deleteSession2 = DHSession(
            peerIdentity: deleteContact.identity,
            peerPublicKey: deleteContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: deleteSession2)
        XCTAssertEqual(2, sessionStore.dhSessionList.count)
        
        // Create identity and sessions to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: keepIdentity.rawValue
        )
        
        let keepSession1 = DHSession(
            peerIdentity: keepContact.identity,
            peerPublicKey: keepContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: keepSession1)
        
        XCTAssertEqual(3, sessionStore.dhSessionList.count)

        // Run
        
        try fsSessionTerminator.deleteAllSessions(with: deleteContact)
        
        // Validate
        
        // All sessions from `deleteContact` should be deleted and all from `keepContact` kept
        XCTAssertEqual(1, sessionStore.dhSessionList.count)
    }
}
