import libthreemaSwift
import ThreemaEssentials

/// Builds the providers a backup is written from and read back into.
///
/// The same set serves both directions, and none of it can be built before the Threema ID is known — on a restore the
/// ID only arrives with the backup itself — so the providers are made at the point of use rather than held from
/// initialization.
struct DataBackupProvidersFactory {

    // MARK: - Private properties

    private let makeProfileStore: (ThreemaIdentity) -> any ProfileStoreProtocol
    private let userSettings: any UserSettingsProtocol
    private let entityManager: EntityManager
    private let makeContactStore: () -> any ContactStoreProtocol
    private let makePushSettingManager: () -> any PushSettingManagerProtocol

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - makeContactStore: Builds the contact store the contacts are read from and written to. Tests pass a stand-in,
    ///     so a restore does not reach the app's shared one.
    ///   - makePushSettingManager: Builds the push setting manager of the contacts and groups. Tests pass one on
    ///     throwaway storage, because the default one opens the app's database.
    init(
        makeProfileStore: @escaping (ThreemaIdentity) -> any ProfileStoreProtocol,
        userSettings: any UserSettingsProtocol,
        entityManager: EntityManager,
        makeContactStore: @escaping () -> any ContactStoreProtocol = { ContactStore.shared() },
        makePushSettingManager: @escaping () -> any PushSettingManagerProtocol = { PushSettingManager() }
    ) {
        self.makeProfileStore = makeProfileStore
        self.userSettings = userSettings
        self.entityManager = entityManager
        self.makeContactStore = makeContactStore
        self.makePushSettingManager = makePushSettingManager
    }

    // MARK: - Internal methods

    func make(identity: ThreemaIdentity) -> DataBackupProviders {
        DataBackupProviders(
            userProfile: UserProfileProvider(
                userIdentity: identity,
                profileStore: makeProfileStore(identity)
            ),
            settings: SettingsProvider(
                userIdentity: identity,
                userSettings: userSettings
            ),
            contacts: ContactProvider(
                userIdentity: identity,
                userSettings: userSettings,
                contactStore: makeContactStore(),
                pushSettingManager: makePushSettingManager(),
                entityManager: entityManager
            ),
            groups: GroupProvider(
                userIdentity: identity,
                pushSettingManager: makePushSettingManager(),
                entityManager: entityManager
            ),
            distributionLists: DistributionListProvider(),
            cspNonces: NonceProvider(entityManager: entityManager),
            polls: PollProvider(userIdentity: identity, entityManager: entityManager),
            conversations: ConversationProvider(userIdentity: identity, entityManager: entityManager)
        )
    }
}
