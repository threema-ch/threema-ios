import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class TaskExecutionRunForwardSecurityRefreshStepsTests: XCTestCase {

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

    func testExecuteGroupTextMessageResendToRejectedByContacts() async throws {
        let sessionStore = InMemoryDHSessionStore()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: backgroundEntityManager,
            serverConnector: serverConnectorMock,
            dhSessionStore: sessionStore
        )

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
        
        // The order of the identities is uses below for validation
        let expectedContactIdentities = [
            noSessionIdentity,
            nonCommittedSessionIdentity,
            committedSessionIdentity,
            noFSSupportIdentity,
        ]

        let expect = expectation(description: "TaskDefinitionRunForwardSecurityRefreshSteps")
        var expectError: Error?

        let task = TaskDefinitionRunForwardSecurityRefreshSteps(with: expectedContactIdentities)
        task.create(frameworkInjector: businessInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        await fulfillment(of: [expect], timeout: 6)

        // Verify
        
        XCTAssertNil(expectError)
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        // One contact doesn't support FS
        XCTAssertEqual(expectedContactIdentities.count - 1, serverConnectorMock.sendMessageCalls.count)
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
