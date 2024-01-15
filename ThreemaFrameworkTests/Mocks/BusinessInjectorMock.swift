//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

    var backgroundPushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    var contactStore: ContactStoreProtocol

    var conversationStore: ConversationStoreProtocol

    var entityManager: EntityManager

    var groupManager: GroupManagerProtocol

    var licenseStore: LicenseStore

    var messageSender: MessageSenderProtocol

    var multiDeviceManager: MultiDeviceManagerProtocol

    var myIdentityStore: MyIdentityStoreProtocol

    var unreadMessages: UnreadMessagesProtocol

    var userSettings: UserSettingsProtocol

    var serverConnector: ServerConnectorProtocol
    
    var settingsStore: SettingsStoreProtocol
    
    var pushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    // MARK: BusinessInternalInjectorProtocol

    var mediatorMessageProtocol: MediatorMessageProtocolProtocol

    var mediatorReflectedProcessor: MediatorReflectedProcessorProtocol

    var messageProcessor: MessageProcessorProtocol
    
    var fsmp: ForwardSecurityMessageProcessor
    
    var dhSessionStore: DHSessionStoreProtocol
    
    var conversationStoreInternal: ThreemaFramework.ConversationStoreInternalProtocol

    var settingsStoreInternal: SettingsStoreInternalProtocol

    var userNotificationCenterManager: UserNotificationCenterManagerProtocol

    var nonceGuard: NonceGuardProtocol

    var blobUploader: BlobUploaderProtocol
    
    var messageRetentionManager: any MessageRetentionManagerModelProtocol

    init(
        backgroundEntityManager: EntityManager,
        backgroundGroupManager: GroupManagerProtocol = GroupManagerMock(),
        backgroundUnreadMessages: UnreadMessagesProtocol = UnreadMessagesMock(),
        backgroundPushSettingManager: PushSettingManagerProtocol = PushSettingManagerMock(),
        contactStore: ContactStoreProtocol = ContactStoreMock(),
        conversationStore: ConversationStoreProtocol & ConversationStoreInternalProtocol = ConversationStoreMock(),
        entityManager: EntityManager,
        groupManager: GroupManagerProtocol = GroupManagerMock(),
        licenseStore: LicenseStore = LicenseStore.shared(),
        messageSender: MessageSenderProtocol = MessageSenderMock(),
        multiDeviceManager: MultiDeviceManagerProtocol = MultiDeviceManagerMock(),
        myIdentityStore: MyIdentityStoreProtocol = MyIdentityStoreMock(),
        unreadMessages: UnreadMessagesProtocol = UnreadMessagesMock(),
        userSettings: UserSettingsProtocol = UserSettingsMock(),
        settingsStore: SettingsStoreInternalProtocol & SettingsStoreProtocol = SettingsStoreMock(),
        serverConnector: ServerConnectorProtocol = ServerConnectorMock(),
        pushSettingManager: PushSettingManagerProtocol = PushSettingManagerMock(),
        mediatorMessageProtocol: MediatorMessageProtocolProtocol = MediatorMessageProtocolMock(),
        mediatorReflectedProcessor: MediatorReflectedProcessorProtocol = MediatorReflectedProcessorMock(),
        messageProcessor: MessageProcessorProtocol = MessageProcessorMock(),
        userNotificationCenterManager: UserNotificationCenterManagerProtocol = UserNotificationCenterManagerMock(),
        nonceGuard: NonceGuardProtocol = NonceGuardMock(),
        blobUploader: BlobUploaderProtocol = BlobUploaderMock(),
        messageRetentionManager: MessageRetentionManagerModelProtocol = MessageRetentionManagerModelMock()
    ) {
        self.backgroundEntityManager = backgroundEntityManager
        self.backgroundGroupManager = backgroundGroupManager
        self.backgroundUnreadMessages = backgroundUnreadMessages
        self.backgroundPushSettingManager = backgroundPushSettingManager
        self.contactStore = contactStore
        self.conversationStore = conversationStore
        self.entityManager = entityManager
        self.groupManager = groupManager
        self.licenseStore = licenseStore
        self.messageSender = messageSender
        self.multiDeviceManager = multiDeviceManager
        self.myIdentityStore = myIdentityStore
        self.unreadMessages = unreadMessages
        self.userSettings = userSettings
        self.serverConnector = serverConnector
        self.pushSettingManager = pushSettingManager
        self.mediatorMessageProtocol = mediatorMessageProtocol
        self.mediatorReflectedProcessor = mediatorReflectedProcessor
        self.messageProcessor = messageProcessor
        self.dhSessionStore = InMemoryDHSessionStore()
        self.fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: myIdentityStore,
            messageSender: DummySender()
        )
        self.settingsStore = settingsStore
        self.conversationStoreInternal = conversationStore
        self.settingsStoreInternal = settingsStore
        self.userNotificationCenterManager = userNotificationCenterManager
        self.nonceGuard = nonceGuard
        self.blobUploader = blobUploader
        self.messageRetentionManager = messageRetentionManager
    }

    class DummySender: ForwardSecurityMessageSenderProtocol {
        func send(message: AbstractMessage) {
            // do nothing
        }
    }
}
