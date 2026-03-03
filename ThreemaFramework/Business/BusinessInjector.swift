//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import Keychain
import RemoteSecretProtocol
import ThreemaEssentials

/// If your code is run in the notification extension (`NotificationService`) you should generally
/// use the already created instance of business injector.
/// Otherwise inconsistencies might occur in the database.
public final class BusinessInjector: NSObject, FrameworkInjectorProtocol {

    /// Shared instance to be used for everything in the UI (MainThread)
    @objc public static let ui = BusinessInjector()
    
    // This must be initialized lazy, because `BusinessInjector` is used in `AppMigration` and
    // the migration of files (see `AppFilesMigration.run()`) must be completed before the `TaskManager`
    // is initialized!
    private lazy var taskManager: TaskManagerProtocol = TaskManager(
        backgroundEntityManager: backgroundEntityManager,
        serverConnector: serverConnector
    )
    // Will be used for none public services, that must be running in the background anyway
    private let backgroundEntityManager: EntityManager

    @objc required init(entityManager: EntityManager) {
        // This `assert` would be nice, than the `BusinessInjector` can only be used when My Identity is present.
        // But in the moment the assert throws if unit tests are running, because e.g.
        // `ContactEntity.setFeatureMask(...` uses an instance of `BusinessInjector`, this should be mocked.
        // There are many issues of this kind!
        // assert(MyIdentityStore.shared().identity != nil, "My identity should be set when using business injector")

        self.runsInBackground = entityManager.hasBackgroundChildContext
        self.entityManager = entityManager

        let persistenceManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: AppLaunchManager.remoteSecretManager
        )

        self.databaseManagerObjC = persistenceManager.databaseManager
        self.dirtyObjectManagerObjC = persistenceManager.dirtyObjectManager

        if entityManager.hasBackgroundChildContext {
            self.backgroundEntityManager = entityManager
        }
        else {
            self.backgroundEntityManager = persistenceManager.backgroundEntityManager
        }
    }

    /// Create `BusinessInjector` for main thread or background (Core Data child context) thread.
    ///
    /// - Parameter forBackgroundProcess: Use this only for special cases (like Notification Extension), in general use
    /// the functions `runInBackground` and `runInBackgroundAndWait` for background threads
    @objc public convenience init(forBackgroundProcess: Bool) {
        let persistenceManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: AppLaunchManager.remoteSecretManager
        )

        if forBackgroundProcess {
            self.init(entityManager: persistenceManager.backgroundEntityManager)
        }
        else {
            self.init(entityManager: persistenceManager.entityManager)
        }
    }

    @objc override public convenience init() {
        self.init(forBackgroundProcess: false)
    }
    
    // MARK: BusinessInjectorProtocol

    public let runsInBackground: Bool
    
    public private(set) lazy var profileStore: any ProfileStoreProtocol = ThreemaFramework
        .ProfileStore(myIdentity: ThreemaIdentity(self.myIdentityStore.identity))

    // Do not mark as lazy, to prevent blocking thread when calling singleton init
    public private(set) var contactStore: ContactStoreProtocol = ContactStore.shared()

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

    @available(*, deprecated, message: "Only use from Objective-C")
    @objc public let databaseManagerObjC: DatabaseManagerProtocolObjc

    @available(*, deprecated, message: "Only use from Objective-C")
    @objc public let dirtyObjectManagerObjC: DirtyObjectManager

    @objc public let entityManager: EntityManager

    public private(set) lazy var groupManager: GroupManagerProtocol = GroupManager(
        myIdentityStore: myIdentityStore,
        contactStore: contactStore,
        taskManager: taskManager,
        userSettings: userSettings,
        entityManager: entityManager,
        groupPhotoSender: {
            GroupPhotoSender()
        }
    )

    @available(*, deprecated, message: "Only use from Objective-C", renamed: "groupManager")
    @objc public private(set) lazy var groupManagerObjC = GroupManager(
        myIdentityStore: myIdentityStore,
        contactStore: contactStore,
        taskManager: taskManager,
        userSettings: userSettings,
        entityManager: entityManager,
        groupPhotoSender: {
            GroupPhotoSender()
        }
    )
    
    public private(set) lazy var distributionListManager: DistributionListManagerProtocol =
        DistributionListManager(entityManager: entityManager)

    // Do not mark as lazy, to prevent blocking thread when calling singleton init
    public private(set) var licenseStore = LicenseStore.shared()

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
            taskManager: taskManager,
            entityManager: entityManager
        )

    // Do not mark as lazy, to prevent blocking thread when calling singleton init
    @objc public private(set) var myIdentityStore: MyIdentityStoreProtocol = MyIdentityStore.shared()

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

    // Do not mark as lazy, to prevent blocking thread when calling singleton init
    @objc public private(set) var userSettings: UserSettingsProtocol = UserSettings.shared()

    public private(set) lazy var settingsStore: any SettingsStoreProtocol = SettingsStore(
        serverConnector: serverConnector,
        myIdentityStore: myIdentityStore,
        contactStore: contactStore,
        userSettings: userSettings,
        taskManager: taskManager
    )
    
    // Do not mark as lazy, to prevent blocking thread when calling singleton init
    public private(set) var serverConnector: ServerConnectorProtocol = ServerConnector.shared()

    public private(set) lazy var pushSettingManager: PushSettingManagerProtocol = PushSettingManager(
        userSettings: userSettings,
        groupManager: groupManager,
        entityManager: entityManager,
        markupParser: MarkupParser(),
        taskManager: taskManager,
        isWorkApp: TargetManager.isBusinessApp
    )

    public private(set) lazy var keychainManager: any KeychainManagerProtocol = KeychainManager(
        remoteSecretManager: AppLaunchManager.remoteSecretManager
    )

    @available(
        *,
        deprecated,
        message: "Only use from Objective-C",
        renamed: "keychainManager"
    )
    @objc public private(set) lazy var keychainManagerObjC: KeychainManager = keychainManager as! KeychainManager

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
                    myIdentityStore: myIdentityStore,
                    contactStore: contactStore,
                    taskManager: taskManager,
                    userSettings: userSettings,
                    entityManager: backgroundEntityManager,
                    groupPhotoSender: {
                        GroupPhotoSender()
                    }
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
                messageSender: messageSender,
                taskManager: taskManager
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

    private(set) lazy var nonceGuard: NonceGuardProtocol = NonceGuard(
        myIdentityStore: myIdentityStore,
        entityManager: backgroundEntityManager
    )

    private(set) lazy var blobUploader: BlobUploaderProtocol =
        BlobUploader(blobURL: BlobURL(serverConnector: self.serverConnector, userSettings: self.userSettings))
}
