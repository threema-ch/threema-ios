import FileUtility
import GroupCalls
import Keychain
import RemoteSecretProtocol
import ThreemaFramework
import UserNotifications

/// Holds the dependencies needed once the app is fully ready (post-RemoteSecret,
/// post-migration). Created by `RootCoordinator` and passed to `AppCoordinator`.
@MainActor
struct AppDependencyContainer {
    let businessInjector: any BusinessInjectorProtocol
    let remoteSecretManager: any RemoteSecretManagerProtocol
    let keychainManager: any KeychainManagerProtocol
    let bootstrap: BootstrapContainer
    let passcodeLock: any PasscodeLockProtocol
    let wcSessionManager: any WCSessionManagerProtocol
    let newMessageToaster: NewMessageToaster
    let incomingMessageManager: IncomingMessageManager
    let typingIndicatorManager: TypingIndicatorManager
    let notificationHandler: NotificationHandler
    let notificationManager: NotificationManager
    let bgTaskManager: ThreemaBGTaskManager
    let globalGroupCallManager: GlobalGroupCallManagerSingleton
    let fileUtility: any FileUtilityProtocol
    let safeManager: any SafeManagerProtocol
    let voIPCallStateManager: VoIPCallStateManager
    let backgroundTaskManager: BackgroundTaskManager
    let blobManager: BlobManager
    let notificationPresenter: NotificationPresenterWrapper
    let userNotificationCenter: any UserNotificationCenterProtocol

    fileprivate init(
        businessInjector: any BusinessInjectorProtocol,
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        bootstrap: BootstrapContainer,
        passcodeLock: any PasscodeLockProtocol,
        wcSessionManager: any WCSessionManagerProtocol,
        newMessageToaster: NewMessageToaster,
        incomingMessageManager: IncomingMessageManager,
        typingIndicatorManager: TypingIndicatorManager,
        notificationHandler: NotificationHandler,
        notificationManager: NotificationManager,
        bgTaskManager: ThreemaBGTaskManager,
        globalGroupCallManager: GlobalGroupCallManagerSingleton,
        fileUtility: any FileUtilityProtocol,
        safeManager: any SafeManagerProtocol,
        voIPCallStateManager: VoIPCallStateManager,
        backgroundTaskManager: BackgroundTaskManager,
        blobManager: BlobManager,
        notificationPresenter: NotificationPresenterWrapper,
        userNotificationCenter: any UserNotificationCenterProtocol
    ) {
        self.businessInjector = businessInjector
        self.remoteSecretManager = remoteSecretManager
        self.keychainManager = keychainManager
        self.bootstrap = bootstrap
        self.passcodeLock = passcodeLock
        self.wcSessionManager = wcSessionManager
        self.newMessageToaster = newMessageToaster
        self.incomingMessageManager = incomingMessageManager
        self.typingIndicatorManager = typingIndicatorManager
        self.notificationHandler = notificationHandler
        self.notificationManager = notificationManager
        self.bgTaskManager = bgTaskManager
        self.globalGroupCallManager = globalGroupCallManager
        self.fileUtility = fileUtility
        self.safeManager = safeManager
        self.voIPCallStateManager = voIPCallStateManager
        self.backgroundTaskManager = backgroundTaskManager
        self.blobManager = blobManager
        self.notificationPresenter = notificationPresenter
        self.userNotificationCenter = userNotificationCenter
    }
}

@MainActor
enum AppDependencyContainerHelper {
    static func makeAndPrepareContainer(
        businessInjector: any BusinessInjectorProtocol,
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        bootstrap: BootstrapContainer,
        passcodeLock: any PasscodeLockProtocol,
        wcSessionManager: any WCSessionManagerProtocol = WCSessionManagerAdapter(),
        newMessageToaster: NewMessageToaster,
        incomingMessageManager: IncomingMessageManager = IncomingMessageManager(),
        typingIndicatorManager: TypingIndicatorManager = TypingIndicatorManager.sharedInstance,
        notificationHandler: NotificationHandler,
        notificationManager: NotificationManager,
        bgTaskManager: ThreemaBGTaskManager = ThreemaBGTaskManager.shared,
        globalGroupCallManager: GlobalGroupCallManagerSingleton = GlobalGroupCallManagerSingleton.shared,
        fileUtility: any FileUtilityProtocol = FileUtility.shared,
        safeManager: any SafeManagerProtocol,
        voIPCallStateManager: VoIPCallStateManager = VoIPCallStateManager.shared,
        backgroundTaskManager: BackgroundTaskManager = BackgroundTaskManager.shared,
        blobManager: BlobManager = BlobManager.shared,
        notificationPresenter: NotificationPresenterWrapper = NotificationPresenterWrapper.shared,
        userNotificationCenter: any UserNotificationCenterProtocol = UNUserNotificationCenter.current()
    ) -> AppDependencyContainer {
        let container = AppDependencyContainer(
            businessInjector: businessInjector,
            remoteSecretManager: remoteSecretManager,
            keychainManager: keychainManager,
            bootstrap: bootstrap,
            passcodeLock: passcodeLock,
            wcSessionManager: wcSessionManager,
            newMessageToaster: newMessageToaster,
            incomingMessageManager: incomingMessageManager,
            typingIndicatorManager: typingIndicatorManager,
            notificationHandler: notificationHandler,
            notificationManager: notificationManager,
            bgTaskManager: bgTaskManager,
            globalGroupCallManager: globalGroupCallManager,
            fileUtility: fileUtility,
            safeManager: safeManager,
            voIPCallStateManager: voIPCallStateManager,
            backgroundTaskManager: backgroundTaskManager,
            blobManager: blobManager,
            notificationPresenter: notificationPresenter,
            userNotificationCenter: userNotificationCenter
        )
        
        /// Ensure we have the identity set before we use the dependencies
        try? MyIdentityStoreHelper.reloadIdentity(from: keychainManager)
        
        // Register the message processor early so the server can deliver offer messages
        // during the passcode phase.
        businessInjector.serverConnector.registerMessageProcessorDelegate(
            delegate: incomingMessageManager
        )
        
        return container
    }
}
