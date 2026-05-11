import Foundation
import Keychain
import RemoteSecretProtocol

public protocol BusinessInjectorProtocol: AnyObject {
    var runsInBackground: Bool { get }
    var contactStore: any ContactStoreProtocol { get }
    var conversationStore: any ConversationStoreProtocol { get }
    var entityManager: EntityManager { get }
    var groupManager: any GroupManagerProtocol { get }
    var distributionListManager: any DistributionListManagerProtocol { get }
    var licenseStore: any LicenseStoreProtocol { get }
    var messageSender: any MessageSenderProtocol { get }
    var multiDeviceManager: any MultiDeviceManagerProtocol { get }
    @available(
        *,
        deprecated,
        message: "To get My Identity use profileStore, and for other functions MyIdentityStore directly"
    )
    var myIdentityStore: any MyIdentityStoreProtocol { get }
    var profileStore: any ProfileStoreProtocol { get }
    var serverConnector: any ServerConnectorProtocol { get }
    var unreadMessages: any UnreadMessagesProtocol { get }
    var messageRetentionManager: any MessageRetentionManagerModelProtocol { get }
    var userSettings: any UserSettingsProtocol { get }
    var settingsStore: any SettingsStoreProtocol { get }
    var pushSettingManager: any PushSettingManagerProtocol { get }
    var keychainManager: any KeychainManagerProtocol { get }
    var workAvailabilityStatusManager: any WorkAvailabilityStatusManagerProtocol { get }
    var workDataFetcher: any WorkDataFetcherProtocol { get }
    
    /// Do work with a background business injector. This runs on the thread of the caller!
    ///
    /// The closure will be called with a `BusinessInjector` initialized with a background Core Data child context. All
    /// services uses the same background Core Data child context. The closure doesn't run implicit in a Core Data
    /// perform block, make your own Core Data perform block if you work with Core Data objects.
    ///
    /// - Note: If the `BusinessInjector` already runs in the background the same one will be returned. Otherwise a new
    /// one will be created.
    ///
    /// - Parameter block: Closure called with background `BusinessInjector`
    func runInBackground<T>(_ block: @escaping (BusinessInjectorProtocol) async throws -> T) async rethrows -> T

    /// Do work with a background business injector. This runs on the thread of the caller!
    ///
    /// The closure will be called with a `BusinessInjector` initialized with a background Core Data child context. All
    /// services uses the same background Core Data child context. The closure doesn't run implicit in a Core Data
    /// perform block, make your own Core Data perform block if you work with Core Data objects.
    ///
    /// - Note: If the `BusinessInjector` already runs in the background the same one will be returned. Otherwise a new
    /// one will be created.
    ///
    /// - Parameter block: Closure called with background `BusinessInjector`
    func runInBackgroundAndWait<T>(_ block: (BusinessInjectorProtocol) throws -> T) rethrows -> T
}

protocol BusinessInternalInjectorProtocol: AnyObject {
    var mediatorMessageProtocol: any MediatorMessageProtocolProtocol { get }
    var mediatorReflectedProcessor: any MediatorReflectedProcessorProtocol { get }
    var messageProcessor: any MessageProcessorProtocol { get }
    var dhSessionStore: any DHSessionStoreProtocol { get }
    var fsmp: ForwardSecurityMessageProcessor { get }
    var conversationStoreInternal: any ConversationStoreInternalProtocol { get }
    var settingsStoreInternal: any SettingsStoreInternalProtocol { get }
    var userNotificationCenterManager: any UserNotificationCenterManagerProtocol { get }
    var nonceGuard: any NonceGuardProtocol { get }
    var blobUploader: any BlobUploaderProtocol { get }
}

typealias FrameworkInjectorProtocol = BusinessInjectorProtocol & BusinessInternalInjectorProtocol
