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

import CocoaLumberjackSwift
import Foundation

/// If your code is run in the notification extension (`NotificationService`) you should in general use already created
/// instance of business injector.
/// Otherwise inconsistencies might occur in the database.
public class BusinessInjector: NSObject, FrameworkInjectorProtocol {

    // MARK: BusinessInjectorProtocol

    @objc public lazy var backgroundEntityManager = EntityManager(withChildContextForBackgroundProcess: true)

    public lazy var backgroundGroupManager: GroupManagerProtocol = GroupManager(
        myIdentityStore,
        contactStore,
        TaskManager(frameworkInjector: self),
        userSettings,
        backgroundEntityManager,
        GroupPhotoSender()
    )
    
    public lazy var backgroundUnreadMessages: UnreadMessagesProtocol = UnreadMessages(
        entityManager: backgroundEntityManager
    )

    public lazy var backgroundPushSettingManager: PushSettingManagerProtocol = PushSettingManager(
        userSettings,
        backgroundGroupManager,
        backgroundEntityManager,
        licenseStore.getRequiresLicenseKey()
    )

    public lazy var contactStore: ContactStoreProtocol = ContactStore.shared()

    public lazy var conversationStore: any ConversationStoreProtocol = ConversationStore(
        userSettings: userSettings,
        pushSettingManager: pushSettingManager,
        groupManager: groupManager,
        entityManager: entityManager,
        taskManager: TaskManager(frameworkInjector: self)
    )
    
    public lazy var entityManager = EntityManager()

    public lazy var groupManager: GroupManagerProtocol = GroupManager(
        myIdentityStore,
        contactStore,
        TaskManager(frameworkInjector: self),
        userSettings,
        entityManager,
        GroupPhotoSender()
    )

    public lazy var licenseStore = LicenseStore.shared()

    public lazy var messageSender: MessageSenderProtocol = MessageSender(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        userSettings: userSettings,
        groupManager: groupManager,
        taskManager: TaskManager(frameworkInjector: self),
        entityManager: entityManager
    )

    public lazy var multiDeviceManager: MultiDeviceManagerProtocol =
        MultiDeviceManager(serverConnector: serverConnector, userSettings: userSettings)

    public lazy var myIdentityStore: MyIdentityStoreProtocol = MyIdentityStore.shared()

    public lazy var unreadMessages: UnreadMessagesProtocol = UnreadMessages(
        entityManager: entityManager
    )
    
    public lazy var messageRetentionManager: MessageRetentionManagerModelProtocol =
        MessageRetentionManagerModel(businessInjector: self)

    @objc public lazy var userSettings: UserSettingsProtocol = UserSettings.shared()

    public lazy var settingsStore: any SettingsStoreProtocol = SettingsStore(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        contactStore: contactStore,
        userSettings: userSettings,
        taskManager: TaskManager(frameworkInjector: self)
    )
    
    public lazy var serverConnector: ServerConnectorProtocol = ServerConnector.shared()

    public lazy var pushSettingManager: PushSettingManagerProtocol = PushSettingManager(
        userSettings,
        groupManager,
        entityManager,
        licenseStore.getRequiresLicenseKey()
    )

    // MARK: BusinessInternalInjectorProtocol

    private var mediatorReflectedProcessorInstance: MediatorReflectedProcessorProtocol?
    private var messageProcessorInstance: MessageProcessorProtocol?
    private var fsmpInstance: ForwardSecurityMessageProcessor?
    private var fsStatusSender: ForwardSecurityStatusSender?
    
    private static var dhSessionStoreInstance: DHSessionStoreProtocol = try! SQLDHSessionStore()

    lazy var mediatorMessageProtocol: MediatorMessageProtocolProtocol = MediatorMessageProtocol(
        deviceGroupKeys: self
            .serverConnector.deviceGroupKeys
    )

    lazy var mediatorReflectedProcessor: MediatorReflectedProcessorProtocol = MediatorReflectedProcessor(
        frameworkInjector: self,
        messageProcessorDelegate: serverConnector
    )
    
    var messageProcessor: MessageProcessorProtocol {
        if messageProcessorInstance == nil {
            messageProcessorInstance = MessageProcessor(
                serverConnector,
                entityManager: backgroundEntityManager,
                fsmp: fsmp,
                nonceGuard: nonceGuard as? NSObject
            )
        }
        return messageProcessorInstance!
    }
    
    @objc var fsmp: ForwardSecurityMessageProcessor {
        if fsmpInstance == nil {
            fsmpInstance = ForwardSecurityMessageProcessor(
                dhSessionStore: dhSessionStore,
                identityStore: myIdentityStore,
                messageSender: MessageSenderAdapter(businessInjector: self)
            )
            
            fsStatusSender = ForwardSecurityStatusSender(entityManager: entityManager)
            fsmpInstance?.addListener(listener: fsStatusSender!)
        }
        return fsmpInstance!
    }
    
    public var dhSessionStore: DHSessionStoreProtocol {
        BusinessInjector.dhSessionStoreInstance
    }

    lazy var conversationStoreInternal: ConversationStoreInternalProtocol =
        conversationStore as! ConversationStoreInternalProtocol

    lazy var settingsStoreInternal: SettingsStoreInternalProtocol = settingsStore as! SettingsStoreInternalProtocol

    lazy var userNotificationCenterManager: UserNotificationCenterManagerProtocol = UserNotificationCenterManager()

    lazy var nonceGuard: NonceGuardProtocol = NonceGuard(entityManager: backgroundEntityManager)

    lazy var blobUploader: BlobUploaderProtocol =
        BlobUploader(blobURL: BlobURL(serverConnector: self.serverConnector, userSettings: self.userSettings))

    class MessageSenderAdapter: ForwardSecurityMessageSenderProtocol {
        private let businessInjector: BusinessInjector

        init(businessInjector: BusinessInjector) {
            self.businessInjector = businessInjector
        }

        func send(message: AbstractMessage) {
            businessInjector.messageSender.sendMessage(abstractMessage: message, isPersistent: true)
        }
    }
}
