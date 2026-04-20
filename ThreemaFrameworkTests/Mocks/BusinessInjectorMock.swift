import Foundation
import Keychain
import KeychainTestHelper
import RemoteSecretProtocol
import RemoteSecretProtocolTestHelper
import ThreemaEssentials
@testable import ThreemaFramework

final class BusinessInjectorMock: FrameworkInjectorProtocol {

    func runInBackground<T>(
        _ block: @escaping (ThreemaFramework.BusinessInjectorProtocol) async throws
            -> T
    ) async rethrows -> T {
        try await block(self)
    }
    
    func runInBackgroundAndWait<T>(_ block: (ThreemaFramework.BusinessInjectorProtocol) throws -> T) rethrows -> T {
        try block(self)
    }

    // MARK: BusinessInjectorProtocol

    var runsInBackground: Bool
    
    var remoteSecretManager: any RemoteSecretManagerProtocol

    var contactStore: ContactStoreProtocol

    var conversationStore: ConversationStoreProtocol

    var entityManager: EntityManager

    var groupManager: GroupManagerProtocol

    var distributionListManager: DistributionListManagerProtocol
    
    var licenseStore: LicenseStore

    var messageSender: MessageSenderProtocol

    var multiDeviceManager: MultiDeviceManagerProtocol

    var myIdentityStore: MyIdentityStoreProtocol

    var profileStore: any ThreemaFramework.ProfileStoreProtocol

    var unreadMessages: UnreadMessagesProtocol

    var userSettings: UserSettingsProtocol

    var serverConnector: ServerConnectorProtocol
    
    var settingsStore: SettingsStoreProtocol
    
    var pushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    var keychainManager: any Keychain.KeychainManagerProtocol

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
        remoteSecretManager: any RemoteSecretManagerProtocol = RemoteSecretManagerMock(),
        contactStore: ContactStoreProtocol = ContactStoreMock(),
        conversationStore: ConversationStoreProtocol & ConversationStoreInternalProtocol = ConversationStoreMock(),
        entityManager: EntityManager,
        groupManager: GroupManagerProtocol = GroupManagerMock(),
        distributionListManager: DistributionListManagerProtocol = DistributionListManagerMock(),
        licenseStore: LicenseStore = LicenseStore.shared(),
        messageSender: MessageSenderProtocol = MessageSenderMock(),
        multiDeviceManager: MultiDeviceManagerProtocol = MultiDeviceManagerMock(),
        myIdentityStore: MyIdentityStoreProtocol = MyIdentityStoreMock(),
        profileStore: ProfileStoreProtocol = ProfileStoreMock(),
        unreadMessages: UnreadMessagesProtocol = UnreadMessagesMock(),
        userSettings: UserSettingsProtocol = UserSettingsMock(),
        settingsStore: SettingsStoreInternalProtocol & SettingsStoreProtocol = SettingsStoreMock(),
        serverConnector: ServerConnectorProtocol = ServerConnectorMock(),
        pushSettingManager: PushSettingManagerProtocol = PushSettingManagerMock(),
        keychainManager: KeychainManagerProtocol = KeychainManagerMock(),
        mediatorMessageProtocol: MediatorMessageProtocolProtocol = MediatorMessageProtocolMock(),
        mediatorReflectedProcessor: MediatorReflectedProcessorProtocol = MediatorReflectedProcessorMock(),
        messageProcessor: MessageProcessorProtocol = MessageProcessorMock(),
        dhSessionStore: DHSessionStoreProtocol = InMemoryDHSessionStore(),
        userNotificationCenterManager: UserNotificationCenterManagerProtocol = UserNotificationCenterManagerMock(),
        nonceGuard: NonceGuardProtocol = NonceGuardMock(),
        blobUploader: BlobUploaderProtocol = BlobUploaderMock(),
        messageRetentionManager: MessageRetentionManagerModelProtocol = MessageRetentionManagerModelMock(),
    ) {
        self.runsInBackground = entityManager.hasBackgroundChildContext
        self.remoteSecretManager = remoteSecretManager
        self.contactStore = contactStore
        self.conversationStore = conversationStore
        self.entityManager = entityManager
        self.groupManager = groupManager
        self.distributionListManager = distributionListManager
        self.licenseStore = licenseStore
        self.messageSender = messageSender
        self.multiDeviceManager = multiDeviceManager
        self.myIdentityStore = myIdentityStore
        self.profileStore = profileStore
        self.unreadMessages = unreadMessages
        self.userSettings = userSettings
        self.serverConnector = serverConnector
        self.pushSettingManager = pushSettingManager
        self.keychainManager = keychainManager
        self.mediatorMessageProtocol = mediatorMessageProtocol
        self.mediatorReflectedProcessor = mediatorReflectedProcessor
        self.messageProcessor = messageProcessor
        self.dhSessionStore = dhSessionStore
        self.fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: myIdentityStore,
            messageSender: messageSender,
            taskManager: TaskManagerMock()
        )
        self.settingsStore = settingsStore
        self.conversationStoreInternal = conversationStore
        self.settingsStoreInternal = settingsStore
        self.userNotificationCenterManager = userNotificationCenterManager
        self.nonceGuard = nonceGuard
        self.blobUploader = blobUploader
        self.messageRetentionManager = messageRetentionManager
        self.keychainManager = keychainManager
    }
}
