import ThreemaEssentials

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

final class AppUpdateStepsTests: XCTestCase {

    private var databasePreparer: TestDatabasePreparer!
    private var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
        entityManager = testDatabase.backgroundEntityManager

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testTwoContactsOneWithInvalidSession() async throws {
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let sessionStore = InMemoryDHSessionStore()
        let businessInjectorMock = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: entityManager,
            dhSessionStore: sessionStore
        )
                
        // Create identity, conversation and sessions to be invalid & terminated
        
        let terminateIdentity = ThreemaIdentity("AAAAAAAA")
        let (terminateContact, terminateConversation) = databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: terminateIdentity.rawValue
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
            "\(businessInjectorMock.myIdentityStore.identity!)+\(terminateIdentity.rawValue)": true,
        ]
        
        XCTAssertEqual(2, sessionStore.dhSessionList.count)
        
        // Create identity and session to be kept
        
        let keepIdentity = ThreemaIdentity("BBBBBBBB")
        let keepContact = databasePreparer.save {
            databasePreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: keepIdentity.rawValue
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
        
        FeatureMaskMock.updateLocalCalls = 0
        let appUpdateSteps = AppUpdateSteps(
            backgroundBusinessInjector: businessInjectorMock,
            featureMask: FeatureMaskMock.self
        )
        try await appUpdateSteps.run()
        
        // Validate
        
        XCTAssertEqual(1, FeatureMaskMock.updateLocalCalls)
        
        XCTAssertEqual(1, contactStoreMock.numberOfUpdateStatusCalls)

        XCTAssertEqual(1, sessionStore.dhSessionList.count)

        // Possible improvement: Check if the correct system message is posted (last message won't return excluded
        // messages)
    }
}
