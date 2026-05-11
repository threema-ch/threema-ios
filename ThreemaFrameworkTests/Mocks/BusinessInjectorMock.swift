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

    var contactStore: any ContactStoreProtocol

    var conversationStore: any ConversationStoreProtocol

    var entityManager: EntityManager

    var groupManager: any GroupManagerProtocol

    var distributionListManager: any DistributionListManagerProtocol
    
    var licenseStore: any LicenseStoreProtocol

    var messageSender: any MessageSenderProtocol

    var multiDeviceManager: any MultiDeviceManagerProtocol

    var myIdentityStore: any MyIdentityStoreProtocol

    var profileStore: any ThreemaFramework.ProfileStoreProtocol

    var unreadMessages: any UnreadMessagesProtocol

    var userSettings: any UserSettingsProtocol

    var serverConnector: any ServerConnectorProtocol
    
    var settingsStore: any SettingsStoreProtocol
    
    var pushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    var keychainManager: any Keychain.KeychainManagerProtocol
    
    var workAvailabilityStatusManager: any ThreemaFramework.WorkAvailabilityStatusManagerProtocol

    var workDataFetcher: any ThreemaFramework.WorkDataFetcherProtocol

    // MARK: BusinessInternalInjectorProtocol

    var mediatorMessageProtocol: any MediatorMessageProtocolProtocol

    var mediatorReflectedProcessor: any MediatorReflectedProcessorProtocol

    var messageProcessor: any MessageProcessorProtocol

    var fsmp: ForwardSecurityMessageProcessor
    
    var dhSessionStore: any DHSessionStoreProtocol
    
    var conversationStoreInternal: any ThreemaFramework.ConversationStoreInternalProtocol

    var settingsStoreInternal: any SettingsStoreInternalProtocol

    var userNotificationCenterManager: any UserNotificationCenterManagerProtocol

    var nonceGuard: any NonceGuardProtocol

    var blobUploader: any BlobUploaderProtocol
    
    var messageRetentionManager: any MessageRetentionManagerModelProtocol

    init(
        remoteSecretManager: any RemoteSecretManagerProtocol = RemoteSecretManagerMock(),
        contactStore: any ContactStoreProtocol = ContactStoreMock(),
        conversationStore: any ConversationStoreProtocol & ConversationStoreInternalProtocol = ConversationStoreMock(),
        entityManager: EntityManager,
        groupManager: any GroupManagerProtocol = GroupManagerMock(),
        distributionListManager: any DistributionListManagerProtocol = DistributionListManagerMock(),
        licenseStore: any LicenseStoreProtocol = LicenseStoreMock(),
        messageSender: any MessageSenderProtocol = MessageSenderMock(),
        multiDeviceManager: any MultiDeviceManagerProtocol = MultiDeviceManagerMock(),
        myIdentityStore: any MyIdentityStoreProtocol = MyIdentityStoreMock(),
        profileStore: any ProfileStoreProtocol = ProfileStoreMock(),
        unreadMessages: any UnreadMessagesProtocol = UnreadMessagesMock(),
        userSettings: any UserSettingsProtocol = UserSettingsMock(),
        settingsStore: any SettingsStoreInternalProtocol & SettingsStoreProtocol = SettingsStoreMock(),
        serverConnector: any ServerConnectorProtocol = ServerConnectorMock(),
        pushSettingManager: any PushSettingManagerProtocol = PushSettingManagerMock(),
        keychainManager: any KeychainManagerProtocol = KeychainManagerMock(),
        mediatorMessageProtocol: any MediatorMessageProtocolProtocol = MediatorMessageProtocolMock(),
        mediatorReflectedProcessor: any MediatorReflectedProcessorProtocol = MediatorReflectedProcessorMock(),
        messageProcessor: any MessageProcessorProtocol = MessageProcessorMock(),
        dhSessionStore: any DHSessionStoreProtocol = InMemoryDHSessionStore(),
        userNotificationCenterManager: any UserNotificationCenterManagerProtocol = UserNotificationCenterManagerMock(),
        nonceGuard: any NonceGuardProtocol = NonceGuardMock(),
        blobUploader: any BlobUploaderProtocol = BlobUploaderMock(),
        messageRetentionManager: any MessageRetentionManagerModelProtocol = MessageRetentionManagerModelMock(),
        workAvailabilityStatusManager: any WorkAvailabilityStatusManagerProtocol = WorkAvailabilityStatusManagerNull(),
        workDataFetcher: any ThreemaFramework.WorkDataFetcherProtocol = WorkDataFetcherMock()
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
        self.workAvailabilityStatusManager = workAvailabilityStatusManager
        self.workDataFetcher = workDataFetcher
    }
}
