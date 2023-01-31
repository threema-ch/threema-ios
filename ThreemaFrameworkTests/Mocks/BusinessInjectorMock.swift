//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import Foundation
@testable import ThreemaFramework

class BusinessInjectorMock: FrameworkInjectorProtocol {

    // MARK: BusinessInjectorProtocol

    var backgroundEntityManager: EntityManager

    var backgroundGroupManager: GroupManagerProtocol

    var backgroundUnreadMessages: UnreadMessagesProtocol

    var contactStore: ContactStoreProtocol

    var entityManager: EntityManager

    var groupManager: GroupManagerProtocol

    var licenseStore: LicenseStore

    var messageSender: MessageSenderProtocol

    var multiDeviceManager: MultiDeviceManagerProtocol

    var myIdentityStore: MyIdentityStoreProtocol

    var userSettings: UserSettingsProtocol

    var serverConnector: ServerConnectorProtocol

    // MARK: BusinessInternalInjectorProtocol

    var mediatorMessageProtocol: MediatorMessageProtocolProtocol

    var messageProcessor: MessageProcessorProtocol
    
    var fsmp: ForwardSecurityMessageProcessor
    
    var dhSessionStore: DHSessionStoreProtocol

    init(
        backgroundEntityManager: EntityManager,
        backgroundGroupManager: GroupManagerProtocol,
        backgroundUnreadMessages: UnreadMessagesProtocol,
        contactStore: ContactStoreProtocol,
        entityManager: EntityManager,
        groupManager: GroupManagerProtocol,
        licenseStore: LicenseStore,
        messageSender: MessageSenderProtocol,
        multiDeviceManager: MultiDeviceManagerProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        serverConnector: ServerConnectorProtocol,
        mediatorMessageProtocol: MediatorMessageProtocolProtocol,
        messageProcessor: MessageProcessorProtocol
    ) {
        self.backgroundEntityManager = backgroundEntityManager
        self.backgroundGroupManager = backgroundGroupManager
        self.backgroundUnreadMessages = backgroundUnreadMessages
        self.contactStore = contactStore
        self.entityManager = entityManager
        self.groupManager = groupManager
        self.licenseStore = licenseStore
        self.messageSender = messageSender
        self.multiDeviceManager = multiDeviceManager
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.serverConnector = serverConnector
        self.mediatorMessageProtocol = mediatorMessageProtocol
        self.messageProcessor = messageProcessor
        self.dhSessionStore = InMemoryDHSessionStore()
        self.fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: myIdentityStore,
            messageSender: DummySender()
        )
    }

    init(entityManager: EntityManager, backgroundEntityManager: EntityManager) {
        self.backgroundEntityManager = backgroundEntityManager
        self.backgroundGroupManager = GroupManagerMock()
        self.backgroundUnreadMessages = UnreadMessagesMock()
        self.contactStore = ContactStoreMock()
        self.entityManager = entityManager
        self.groupManager = GroupManagerMock()
        self.licenseStore = LicenseStore.shared()
        self.messageSender = MessageSenderMock()
        self.multiDeviceManager = MultiDeviceManagerMock()
        self.myIdentityStore = MyIdentityStoreMock()
        self.userSettings = UserSettingsMock()
        self.serverConnector = ServerConnectorMock()
        self.mediatorMessageProtocol = MediatorMessageProtocolMock()
        self.messageProcessor = MessageProcessorMock()
        self.dhSessionStore = InMemoryDHSessionStore()
        self.fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: myIdentityStore,
            messageSender: DummySender()
        )
    }
    
    class DummySender: ForwardSecurityMessageSenderProtocol {
        func send(message: AbstractMessage) {
            // do nothing
        }
    }
}
