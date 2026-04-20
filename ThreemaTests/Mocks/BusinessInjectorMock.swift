import Foundation
import Keychain
import KeychainTestHelper
import RemoteSecretProtocol
import RemoteSecretProtocolTestHelper
@testable import Threema

final class BusinessInjectorMock: BusinessInjectorProtocol {

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
    
    var remoteSecretManager: RemoteSecretManagerProtocol

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

    var settingsStore: SettingsStoreProtocol

    var serverConnector: ServerConnectorProtocol
    
    var messageRetentionManager: any MessageRetentionManagerModelProtocol
        
    var pushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    var keychainManager: KeychainManagerProtocol

    init(
        runsInBackground: Bool = false,
        remoteSecretManager: RemoteSecretManagerProtocol = RemoteSecretManagerMock(),
        contactStore: ContactStoreProtocol = ContactStoreMock(),
        conversationStore: ConversationStoreProtocol = ConversationStoreMock(),
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
        settingsStore: SettingsStoreProtocol = SettingsStoreMock(),
        serverConnector: ServerConnectorProtocol = ServerConnectorMock(),
        messageRetentionManager: any MessageRetentionManagerModelProtocol = MessageRetentionManagerModelMock(),
        pushSettingManager: PushSettingManagerProtocol = PushSettingManagerMock(),
        keychainManager: KeychainManagerProtocol = KeychainManagerMock()
    ) {
        self.runsInBackground = runsInBackground
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
        self.settingsStore = settingsStore
        self.serverConnector = serverConnector
        self.messageRetentionManager = messageRetentionManager
        self.pushSettingManager = pushSettingManager
        self.keychainManager = keychainManager
    }
}
