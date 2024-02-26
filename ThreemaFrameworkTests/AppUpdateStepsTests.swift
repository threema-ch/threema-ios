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
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

final class AppUpdateStepsTests: XCTestCase {

    private var databasePreparer: DatabasePreparer!
    private var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema")

        let (_, mainContext, childContext) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        let databaseBackgroundContext = DatabaseContext(mainContext: mainContext, backgroundContext: childContext)
        databasePreparer = DatabasePreparer(context: mainContext)
        entityManager = EntityManager(databaseContext: databaseBackgroundContext)
    }

    func testTwoContactsOneWithInvalidSession() async throws {
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let sessionStore = InMemoryDHSessionStore()
        let businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: entityManager,
            contactStore: contactStoreMock,
            entityManager: entityManager,
            dhSessionStore: sessionStore
        )
                
        // Create identity, conversation and sessions to be invalid & terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let (terminateContact, terminateConversation) = databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: terminateIdentity.string
            )
            
            // System messages will only be posted if we have a conversation and we need it to initialize the
            // `MessageFetcher`
            let conversation = databasePreparer.createConversation(contactEntity: contact)
            
            return (contact, conversation)
        }
        
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
        
        // Mark sessions of `terminateIdentity` as invalid
        sessionStore.hasInvalidSessions = [
            "\(businessInjectorMock.myIdentityStore.identity!)+\(terminateIdentity.string)": true,
        ]
        
        XCTAssertEqual(2, sessionStore.dhSessionList.count)
        
        // Create identity and session to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.save {
            databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: keepIdentity.string
            )
        }
        
        let keepSession = DHSession(
            peerIdentity: keepContact.identity,
            peerPublicKey: keepContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: keepSession)
        
        XCTAssertEqual(3, sessionStore.dhSessionList.count)
        
        // Run
        
        let expectation = expectation(description: "Steps completed")
        
        let appUpdateSteps = AppUpdateSteps(backgroundBusinessInjector: businessInjectorMock)
        appUpdateSteps.run {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation])
        
        // Validate
        
        XCTAssertEqual(1, contactStoreMock.numberOfSynchronizeAddressBookCalls)

        XCTAssertEqual(1, sessionStore.dhSessionList.count)

        // Check if the correct system message is posted
        let messageFetcher = MessageFetcher(for: terminateConversation, with: entityManager)
        let lastMessage = try XCTUnwrap(messageFetcher.lastMessage() as? SystemMessage)
        // TODO: (IOS-4429) SystemMessage.SystemMessageType is not Equatable, thus we use the "old" API
        XCTAssertEqual(kSystemMessageFsIllegalSessionState, lastMessage.type.intValue)
    }
}
