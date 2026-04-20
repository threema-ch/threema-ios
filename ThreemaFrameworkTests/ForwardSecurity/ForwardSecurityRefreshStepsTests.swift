import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class ForwardSecurityRefreshStepsTests: XCTestCase {

    private var databasePreparer: TestDatabasePreparer!
    private var backgroundEntityManager: EntityManager!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
        backgroundEntityManager = testDatabase.backgroundEntityManager

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testBasicRun() async throws {
        let sessionStore = InMemoryDHSessionStore()
        let messageSenderMock = MessageSenderMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: backgroundEntityManager,
            messageSender: messageSenderMock,
            dhSessionStore: sessionStore
        )
                
        // TODO: (IOS-4567) Remove
        let taskManagerMock = TaskManagerMock()
        
        // Identity with no session
        let noSessionIdentity = ThreemaIdentity("AAAAAAAA")
        _ = createFSEnabledContact(for: noSessionIdentity)
        
        // Identity with a non-committed session
        let nonCommittedSessionIdentity = ThreemaIdentity("BBBBBBBB")
        let nonCommittedSessionContact = createFSEnabledContact(for: nonCommittedSessionIdentity)
        let notCommittedSession = DHSession(
            peerIdentity: nonCommittedSessionContact.identity,
            peerPublicKey: nonCommittedSessionContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        try sessionStore.storeDHSession(session: notCommittedSession)
        
        // Identity with a committed session
        let committedSessionIdentity = ThreemaIdentity("CCCCCCCC")
        let committedSessionContact = createFSEnabledContact(for: committedSessionIdentity)
        let committedSession = DHSession(
            peerIdentity: committedSessionContact.identity,
            peerPublicKey: committedSessionContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        committedSession.newSessionCommitted = true
        try sessionStore.storeDHSession(session: committedSession)
        
        // Identity with contact that doesn't support FS
        let noFSSupportIdentity = ThreemaIdentity("DDDDDDDD")
        databasePreparer.save {
            databasePreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: noFSSupportIdentity.rawValue
            )
        }
        
        // Identity with contact, but not involved in refresh steps run
        let notInvolvedIdentity = ThreemaIdentity("EEEEEEEE")
        let notInvolvedContact = createFSEnabledContact(for: notInvolvedIdentity)
        let notInvolvedSession = DHSession(
            peerIdentity: notInvolvedContact.identity,
            peerPublicKey: notInvolvedContact.publicKey,
            identityStore: businessInjectorMock.myIdentityStore
        )
        notInvolvedSession.newSessionCommitted = true
        try sessionStore.storeDHSession(session: notInvolvedSession)
        
        // We should have 5 stored contacts
        XCTAssertEqual(5, backgroundEntityManager.entityFetcher.contactEntities()!.count)
        
        // There should now be 3 sessions
        XCTAssertEqual(3, sessionStore.dhSessionList.count)
        
        // Run
        
        let fsRefreshSteps = ForwardSecurityRefreshSteps(
            backgroundBusinessInjector: businessInjectorMock,
            taskManager: taskManagerMock
        )
        
        // The order of the identities is uses below for validation
        let expectedContactIdentities = [
            noSessionIdentity,
            nonCommittedSessionIdentity,
            committedSessionIdentity,
            noFSSupportIdentity,
        ]
        
        await fsRefreshSteps.run(for: expectedContactIdentities)
        
        // Verify
        
        // TODO: (IOS-4567) Reenable
        
        // There should now be 4 sessions: 3 form before and one from the no session contact
        // XCTAssertEqual(4, sessionStore.dhSessionList.count)
        
        // For 3 of the 4 contacts a message should have been enqueued
        // XCTAssertEqual(3, messageSenderMock.sentAbstractMessagesQueue.count)
        
        // Validate no session contact
        // let noSessionMessage = try XCTUnwrap(
        //     messageSenderMock.sentAbstractMessagesQueue[0] as? ForwardSecurityEnvelopeMessage
        // )
        // let noSessionInitMessage = try XCTUnwrap(noSessionMessage.data as? ForwardSecurityDataInit)
        // let noSessionSession = try XCTUnwrap(sessionStore.bestDHSession(
        //     myIdentity: businessInjectorMock.myIdentityStore.identity,
        //     peerIdentity: noSessionIdentity.rawValue
        // ))
        // XCTAssertEqual(noSessionSession.id, noSessionInitMessage.sessionID)
        
        // Validate non-committed session contact
        // let nonCommittedSessionMessage = try XCTUnwrap(
        //     messageSenderMock.sentAbstractMessagesQueue[1] as? ForwardSecurityEnvelopeMessage
        // )
        // let nonCommittedSessionInitMessage = try XCTUnwrap(nonCommittedSessionMessage.data as?
        // ForwardSecurityDataInit)
        // XCTAssertEqual(notCommittedSession.id, nonCommittedSessionInitMessage.sessionID)
        
        // Validate committed session contact
        // let committedSessionMessage = try XCTUnwrap(
        //     messageSenderMock.sentAbstractMessagesQueue[2] as? ForwardSecurityEnvelopeMessage
        // )
        // let committedSessionDataMessage = try XCTUnwrap(committedSessionMessage.data as? ForwardSecurityDataMessage)
        // XCTAssertEqual(committedSession.id, committedSessionDataMessage.sessionID)
        // There is no easy way to verify if the message is an `empty` message as `ForwardSecurityMessageProcessor` is
        // not mockable
        
        // TODO: (IOS-4567) Remove
        
        XCTAssertEqual(1, taskManagerMock.addedTasks.count)
        let runForwardSecurityRefreshStepsTask = try XCTUnwrap(
            taskManagerMock.addedTasks[0] as? TaskDefinitionRunForwardSecurityRefreshSteps
        )
        XCTAssertEqual(expectedContactIdentities, runForwardSecurityRefreshStepsTask.contactIdentities)
    }
    
    private func createFSEnabledContact(for identity: ThreemaIdentity) -> ContactEntity {
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: identity.rawValue
            )
            contact.setFeatureMask(to: 255)
            return contact
        }
    }
}
