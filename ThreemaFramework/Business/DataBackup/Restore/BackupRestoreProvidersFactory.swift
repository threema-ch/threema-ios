import libthreemaSwift
import ThreemaEssentials

/// Builds the providers a backup is written from and read back into.
///
/// The same set serves both directions, and none of it can be built before the Threema ID is known — on a restore the
/// ID only arrives with the backup itself — so the providers are made at the point of use rather than held from
/// initialization.
struct BackupRestoreProvidersFactory {

    // MARK: - Private properties

    private let makeProfileStore: (ThreemaIdentity) -> any ProfileStoreProtocol
    private let userSettings: any UserSettingsProtocol
    private let entityManager: EntityManager

    // MARK: - Lifecycle

    init(
        makeProfileStore: @escaping (ThreemaIdentity) -> any ProfileStoreProtocol,
        userSettings: any UserSettingsProtocol,
        entityManager: EntityManager
    ) {
        self.makeProfileStore = makeProfileStore
        self.userSettings = userSettings
        self.entityManager = entityManager
    }

    // MARK: - Internal methods

    func make(identity: ThreemaIdentity) -> BackupRestoreProviders {
        BackupRestoreProviders(
            userProfile: UserProfileProvider(
                userIdentity: identity,
                profileStore: makeProfileStore(identity)
            ),
            settings: SettingsProvider(
                userIdentity: identity,
                userSettings: userSettings
            ),
            cspNonces: NonceProvider(entityManager: entityManager),
            contacts: ContactProvider(
                userIdentity: identity,
                userSettings: userSettings,
                contactStore: ContactStore.shared(),
                pushSettingManager: PushSettingManager(),
                entityManager: entityManager
            ),
            groups: GroupProvider(
                userIdentity: identity,
                pushSettingManager: PushSettingManager(),
                entityManager: entityManager
            ),
            distributionLists: DistributionListProvider(),
            polls: PollProvider(userIdentity: identity, entityManager: entityManager),
            conversations: ConversationProvider()
        )
    }
}
