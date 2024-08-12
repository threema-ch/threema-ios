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
public final class BusinessInjector: NSObject, FrameworkInjectorProtocol {

    private let taskManager: TaskManagerProtocol
    // Will be used for none public services, that must be running in the background anyway
    private let backgroundEntityManager: EntityManager

    @objc required init(entityManager: EntityManager) {
        self.runsInBackground = entityManager.hasBackgroundChildContext
        self.entityManager = entityManager

        if entityManager.hasBackgroundChildContext {
            self.backgroundEntityManager = entityManager
        }
        else {
            self.backgroundEntityManager = EntityManager(withChildContextForBackgroundProcess: true)
        }

        self.taskManager = TaskManager(backgroundEntityManager: backgroundEntityManager)
    }

    /// Create `BusinessInjector` for main thread or background (Core Data child context) thread.
    ///
    /// - Parameter forBackgroundProcess: Use this only for special cases (like Notification Extension), in general use
    /// the functions `runInBackground` and `runInBackgroundAndWait` for background threads
    public convenience init(forBackgroundProcess: Bool) {
        if forBackgroundProcess {
            self.init(entityManager: EntityManager(withChildContextForBackgroundProcess: true))
        }
        else {
            self.init(entityManager: EntityManager())
        }
    }

    @objc override public convenience init() {
        self.init(forBackgroundProcess: false)
    }

    // MARK: BusinessInjectorProtocol

    public let runsInBackground: Bool

    public private(set) lazy var contactStore: ContactStoreProtocol = ContactStore.shared()

    public private(set) lazy var conversationStore: any ConversationStoreProtocol = ConversationStore(
        userSettings: userSettings,
        pushSettingManager: pushSettingManager,
        groupManager: groupManager,
        entityManager: entityManager,
        taskManager: taskManager
    )

    @available(*, deprecated, message: "Only use from Objective-C", renamed: "conversationStore")
    @objc public private(set) lazy var conversationStoreObjC = ConversationStore(
        userSettings: userSettings,
        pushSettingManager: pushSettingManager,
        groupManager: groupManager,
        entityManager: entityManager,
        taskManager: taskManager
    )

    @objc public let entityManager: EntityManager

    public private(set) lazy var groupManager: GroupManagerProtocol = GroupManager(
        myIdentityStore,
        contactStore,
        taskManager,
        userSettings,
        entityManager,
        GroupPhotoSender()
    )

    @available(*, deprecated, message: "Only use from Objective-C", renamed: "groupManager")
    @objc public private(set) lazy var groupManagerObjC = GroupManager(
        myIdentityStore,
        contactStore,
        taskManager,
        userSettings,
        entityManager,
        GroupPhotoSender()
    )
    
    public private(set) lazy var distributionListManager: DistributionListManagerProtocol =
        DistributionListManager(entityManager: entityManager)

    public private(set) lazy var licenseStore = LicenseStore.shared()

    public private(set) lazy var messageSender: MessageSenderProtocol = MessageSender(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        userSettings: userSettings,
        groupManager: groupManager,
        taskManager: taskManager,
        entityManager: entityManager
    )

    @available(*, deprecated, message: "Only use from Objective-C", renamed: "messageSender")
    @objc public private(set) lazy var messageSenderObjC = MessageSender(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        userSettings: userSettings,
        groupManager: groupManager,
        taskManager: taskManager,
        entityManager: entityManager
    )

    public private(set) lazy var multiDeviceManager: MultiDeviceManagerProtocol =
        MultiDeviceManager(
            serverConnector: serverConnector,
            contactStore: contactStore,
            userSettings: userSettings,
            entityManager: entityManager
        )

    public private(set) lazy var myIdentityStore: MyIdentityStoreProtocol = MyIdentityStore.shared()

    public lazy var unreadMessages: UnreadMessagesProtocol = UnreadMessages(
        entityManager: entityManager,
        taskManager: taskManager
    )
    
    @available(*, deprecated, message: "Only use from Objective-C", renamed: "unreadMessages")
    @objc public private(set) lazy var unreadMessagesObjC = UnreadMessages(
        entityManager: entityManager,
        taskManager: taskManager
    )

    public private(set) lazy var messageRetentionManager: MessageRetentionManagerModelProtocol =
        MessageRetentionManagerModel(
            userSettings: userSettings,
            unreadMessages: unreadMessages,
            groupManager: groupManager,
            entityManager: entityManager
        )

    @objc public private(set) lazy var userSettings: UserSettingsProtocol = UserSettings.shared()

    public private(set) lazy var settingsStore: any SettingsStoreProtocol = SettingsStore(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        contactStore: contactStore,
        userSettings: userSettings,
        taskManager: taskManager
    )
    
    public private(set) lazy var serverConnector: ServerConnectorProtocol = ServerConnector.shared()

    public private(set) lazy var pushSettingManager: PushSettingManagerProtocol = PushSettingManager(
        userSettings,
        groupManager,
        entityManager,
        taskManager,
        licenseStore.getRequiresLicenseKey()
    )

    public func runInBackground<T>(
        _ block: @escaping (BusinessInjectorProtocol) async throws -> T
    ) async rethrows
        -> T {
        if entityManager.hasBackgroundChildContext {
            try await block(self)
        }
        else {
            try await block(BusinessInjector(forBackgroundProcess: true))
        }
    }

    public func runInBackgroundAndWait<T>(_ block: (BusinessInjectorProtocol) throws -> T) rethrows -> T {
        if entityManager.hasBackgroundChildContext {
            try block(self)
        }
        else {
            try block(BusinessInjector(forBackgroundProcess: true))
        }
    }

    // MARK: BusinessInternalInjectorProtocol

    private var mediatorReflectedProcessorInstance: MediatorReflectedProcessorProtocol?
    private var messageProcessorInstance: MessageProcessorProtocol?
    private var fsmpInstance: ForwardSecurityMessageProcessor?
    private var fsStatusSender: ForwardSecurityStatusSender?
    
    private static var dhSessionStoreInstance: DHSessionStoreProtocol = try! SQLDHSessionStore()

    private(set) lazy var mediatorMessageProtocol: MediatorMessageProtocolProtocol = MediatorMessageProtocol(
        deviceGroupKeys: self
            .serverConnector.deviceGroupKeys
    )

    private(set) lazy var mediatorReflectedProcessor: MediatorReflectedProcessorProtocol = MediatorReflectedProcessor(
        frameworkInjector: self,
        messageProcessorDelegate: serverConnector
    )
    
    var messageProcessor: MessageProcessorProtocol {
        if messageProcessorInstance == nil {
            messageProcessorInstance = MessageProcessor(
                serverConnector,
                groupManager: GroupManager(
                    myIdentityStore,
                    contactStore,
                    taskManager,
                    userSettings,
                    backgroundEntityManager,
                    GroupPhotoSender()
                ),
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
                messageSender: messageSender
            )
            
            fsStatusSender = ForwardSecurityStatusSender(entityManager: entityManager)
            fsmpInstance?.addListener(listener: fsStatusSender!)
        }
        return fsmpInstance!
    }
    
    public var dhSessionStore: DHSessionStoreProtocol {
        BusinessInjector.dhSessionStoreInstance
    }

    private(set) lazy var conversationStoreInternal: ConversationStoreInternalProtocol =
        conversationStore as! ConversationStoreInternalProtocol

    private(set) lazy var settingsStoreInternal: SettingsStoreInternalProtocol =
        settingsStore as! SettingsStoreInternalProtocol

    private(set) lazy var userNotificationCenterManager: UserNotificationCenterManagerProtocol =
        UserNotificationCenterManager()

    private(set) lazy var nonceGuard: NonceGuardProtocol = NonceGuard(entityManager: backgroundEntityManager)

    private(set) lazy var blobUploader: BlobUploaderProtocol =
        BlobUploader(blobURL: BlobURL(serverConnector: self.serverConnector, userSettings: self.userSettings))
}
