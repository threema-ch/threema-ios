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

final class AppSetupStepsTests: XCTestCase {

    private let myIdentityStoreMock = MyIdentityStoreMock()
    private let sessionStore = InMemoryDHSessionStore()
    private let messageSenderMock = MessageSenderMock()
    private let taskManagerMock = TaskManagerMock()
    private let contactStoreMock = ContactStoreMock(callOnCompletion: true)
    private let userSettingsMock = UserSettingsMock()
    
    private var databasePreparer: DatabasePreparer!
    private var backgroundEntityManager: EntityManager!
    private var businessInjectorMock: FrameworkInjectorProtocol!
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema")

        let (_, mainContext, childContext) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        let databaseBackgroundContext = DatabaseContext(mainContext: mainContext, backgroundContext: childContext)
        databasePreparer = DatabasePreparer(context: mainContext)
        backgroundEntityManager = EntityManager(
            databaseContext: databaseBackgroundContext,
            myIdentityStore: myIdentityStoreMock
        )
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
            taskManger: taskManagerMock,
            featureMask: FeatureMaskMock.self,
            contactPhotoSender: ContactPhotoSenderMock.self
        )
        try await appSetupSteps.run()
        
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
        //     peerIdentity: conversationAndGroupIdentity.string
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
            taskManger: taskManagerMock,
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
                publicKey: MockData.generatePublicKey(),
                identity: identity.string
            )
            contact.featureMask = NSNumber(value: 255)
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
        
        let groupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: creator)
        
        let groupManager = GroupManager(
            myIdentityStoreMock,
            contactStoreMock,
            taskManagerMock,
            userSettingsMock,
            backgroundEntityManager,
            GroupPhotoSenderMock()
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            groupManager.createOrUpdateDB(
                for: groupIdentity,
                members: Set(members.map(\.string)),
                systemMessageDate: .now,
                sourceCaller: .local
            )
            .done { group in
                if let group {
                    continuation.resume(returning: group)
                }
                else {
                    continuation.resume(throwing: AppSetupStepsTestsError.noGroupCreated)
                }
            }
            .catch { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
