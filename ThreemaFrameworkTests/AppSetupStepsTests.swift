import ThreemaEssentials

import ThreemaProtocols
import XCTest

import RemoteSecretProtocolTestHelper
@testable import ThreemaFramework

final class AppSetupStepsTests: XCTestCase {

    private let myIdentityStoreMock = MyIdentityStoreMock()
    private let sessionStore = InMemoryDHSessionStore()
    private let messageSenderMock = MessageSenderMock()
    private let taskManagerMock = TaskManagerMock()
    private let contactStoreMock = ContactStoreMock(callOnCompletion: true)
    private let userSettingsMock = UserSettingsMock()

    private var databasePreparer: TestDatabasePreparer!
    private var backgroundEntityManager: EntityManager!
    private var businessInjectorMock: FrameworkInjectorProtocol!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
        backgroundEntityManager = testDatabase.backgroundEntityManager

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testBasicRun() async throws {
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        
        businessInjectorMock = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: backgroundEntityManager,
            groupManager: groupManagerMock,
            messageSender: messageSenderMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            dhSessionStore: sessionStore
        )
        
        // TODO: (IOS-4567) Remove
        let taskManagerMock = TaskManagerMock()
        
        // Identity with conversation or in no group
        let nonSolicitedIdentity = ThreemaIdentity("AAAAAAAA")
        _ = createFSEnabledContact(for: nonSolicitedIdentity)
        
        // Identity with a conversation and in groups
        let conversationAndGroupIdentity = ThreemaIdentity("BBBBBBBB")
        let conversationAndGroupContact = createFSEnabledContact(for: conversationAndGroupIdentity)
        createConversation(for: conversationAndGroupContact)
        
        // Create own group
        let ownGroupMembers = [
            ThreemaIdentity(businessInjectorMock.myIdentityStore.identity),
            conversationAndGroupIdentity,
        ]
        let ownGroup = try await createGroup(
            with: ThreemaIdentity(businessInjectorMock.myIdentityStore.identity),
            and: ownGroupMembers
        )
        groupManagerMock.getGroupReturns.append(ownGroup)
        
        // Create other group
        let otherGroupMembers = [
            ThreemaIdentity(businessInjectorMock.myIdentityStore.identity),
            conversationAndGroupIdentity,
        ]
        let otherGroup = try await createGroup(with: conversationAndGroupIdentity, and: otherGroupMembers)
        groupManagerMock.getGroupReturns.append(otherGroup)
        
        // Run
        
        FeatureMaskMock.updateLocalCalls = 0
        ContactPhotoSenderMock.numberOfSendProfileRequestCalls = 0
        let appSetupSteps = AppSetupSteps(
            backgroundBusinessInjector: businessInjectorMock,
            taskManager: taskManagerMock,
            featureMask: FeatureMaskMock.self,
            contactPhotoSender: ContactPhotoSenderMock.self
        )
        try await appSetupSteps.run()
        
        // wait 2 seconds because own group restore run in a own task
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for task; sync own groups")], timeout: 2.0)
        
        // Validate
        
        // Update own feature mask
        XCTAssertEqual(1, FeatureMaskMock.updateLocalCalls)
        
        // All contacts should only be refreshed once
        XCTAssertEqual(1, contactStoreMock.numberOfUpdateStatusCalls)
        
        // We have 1 solicited contact...
        
        // Validate one contact with a conversation and in groups that has no existing FS session
        // TODO: (IOS-4567) Reenable
        // XCTAssertEqual(1, messageSenderMock.sentAbstractMessagesQueue.count)
        // let noSessionMessage = try XCTUnwrap(
        //     messageSenderMock.sentAbstractMessagesQueue[0] as? ForwardSecurityEnvelopeMessage
        // )
        // let noSessionInitMessage = try XCTUnwrap(noSessionMessage.data as? ForwardSecurityDataInit)
        // let noSessionSession = try XCTUnwrap(sessionStore.bestDHSession(
        //     myIdentity: businessInjectorMock.myIdentityStore.identity,
        //     peerIdentity: conversationAndGroupIdentity.rawValue
        // ))
        // XCTAssertEqual(noSessionSession.id, noSessionInitMessage.sessionID)
        
        // Send profile picture request for single solicited contact
        // TODO: (IOS-4567) Reenable
        // XCTAssertEqual(1, ContactPhotoSenderMock.numberOfSendProfileRequestCalls)
        
        // One own group
        XCTAssertEqual(1, groupManagerMock.syncCalls.count)
        
        // One other group
        XCTAssertEqual(1, groupManagerMock.sendSyncRequestCalls.count)
        
        // TODO: (IOS-4567) Remove
        
        XCTAssertEqual(1, taskManagerMock.addedTasks.count)
        let runForwardSecurityRefreshStepsTask = try XCTUnwrap(
            taskManagerMock.addedTasks[0] as? TaskDefinitionRunForwardSecurityRefreshSteps
        )
        XCTAssertEqual([conversationAndGroupIdentity], runForwardSecurityRefreshStepsTask.contactIdentities)
    }
    
    func testDoNotRunIfMultiDeviceIsRegistered() async throws {
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        let settingsStoreMock = SettingsStoreMock()
        
        businessInjectorMock = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: backgroundEntityManager,
            groupManager: groupManagerMock,
            messageSender: messageSenderMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            settingsStore: settingsStoreMock,
            dhSessionStore: sessionStore
        )
        
        // TODO: (IOS-4567) Remove
        let taskManagerMock = TaskManagerMock()
        
        settingsStoreMock.isMultiDeviceRegistered = true
        
        // Run
        
        FeatureMaskMock.updateLocalCalls = 0
        ContactPhotoSenderMock.numberOfSendProfileRequestCalls = 0
        let appSetupSteps = AppSetupSteps(
            backgroundBusinessInjector: businessInjectorMock,
            taskManager: taskManagerMock,
            featureMask: FeatureMaskMock.self,
            contactPhotoSender: ContactPhotoSenderMock.self
        )
        try await appSetupSteps.run()
        
        // Validate
        
        XCTAssertEqual(0, FeatureMaskMock.updateLocalCalls)
        XCTAssertEqual(0, contactStoreMock.numberOfUpdateStatusCalls)
        XCTAssertEqual(0, messageSenderMock.sentAbstractMessagesQueue.count)
        XCTAssertEqual(0, ContactPhotoSenderMock.numberOfSendProfileRequestCalls)
        XCTAssertEqual(0, groupManagerMock.syncCalls.count)
        XCTAssertEqual(0, groupManagerMock.sendSyncRequestCalls.count)

        // TODO: (IOS-4567) Remove
        XCTAssertEqual(0, taskManagerMock.addedTasks.count)
    }
        
    // MARK: - Private helper

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
    
    private func createConversation(for contactEntity: ContactEntity) {
        databasePreparer.save {
            let conversation = databasePreparer.createConversation(contactEntity: contactEntity)
            conversation.lastUpdate = .now
        }
    }
    
    enum AppSetupStepsTestsError: Error {
        case noGroupCreated
    }
    
    private func createGroup(
        with creator: ThreemaIdentity,
        and members: [ThreemaIdentity]
    ) async throws -> Group {
        
        let groupIdentity = GroupIdentity(id: BytesUtility.generateGroupID(), creator: creator)
        
        let groupManager = GroupManager(
            myIdentityStore: myIdentityStoreMock,
            contactStore: contactStoreMock,
            taskManager: taskManagerMock,
            userSettings: userSettingsMock,
            entityManager: backgroundEntityManager,
            groupPhotoSender: {
                GroupPhotoSenderMock()
            }
        )
        
        guard let group = try await groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.rawValue)),
            systemMessageDate: .now,
            sourceCaller: .local
        ) else {
            throw AppSetupStepsTestsError.noGroupCreated
        }

        return group
    }
}
