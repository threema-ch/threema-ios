//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

class ForwardSecuritySessionTerminatorTests: XCTestCase {

    private var databaseMainContext: DatabaseContext!
    private var databasePreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema")

        let (_, mainContext, _) = DatabasePersistentContext.devNullContext()
        databaseMainContext = DatabaseContext(mainContext: mainContext, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainContext)
    }
    
    func testTerminateAllSessionsWithMultipleToTerminate() throws {
        let sessionStore = InMemoryDHSessionStore()
        let messageSenderMock = MessageSenderMock()
        let entityManger = EntityManager(databaseContext: databaseMainContext)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManger,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: terminateIdentity.string
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
            publicKey: MockData.generatePublicKey(),
            identity: keepIdentity.string
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
            with: terminateContact,
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
        let entityManger = EntityManager(databaseContext: databaseMainContext)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManger,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: terminateIdentity.string
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
            with: terminateContact,
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
        let entityManger = EntityManager(databaseContext: databaseMainContext)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManger,
            messageSender: messageSenderMock
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity to be terminated with no existing session
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let terminateContact = databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: terminateIdentity.string
        )
        
        // Create identity and sessions to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: keepIdentity.string
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
            with: terminateContact,
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
        let entityManger = EntityManager(databaseContext: databaseMainContext)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: entityManger
        )
        let fsSessionTerminator = try ForwardSecuritySessionTerminator(
            businessInjector: businessInjectorMock,
            store: sessionStore
        )
        
        // Create identity and sessions to be deleted
        
        let deleteIdentity = ThreemaIdentity("AAAAAAAA")
        let deleteContact = databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: deleteIdentity.string
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
            publicKey: MockData.generatePublicKey(),
            identity: keepIdentity.string
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
