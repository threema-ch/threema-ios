import CocoaLumberjackSwift
import Foundation
import RemoteSecretProtocol

public final class PersistenceManager {
    private let remoteSecretManager: RemoteSecretManagerProtocol

    /// Initialize Persistence
    /// - Parameters:
    ///   - appGroup: Value of App Group Entitlement, used for accessing the app storage (physical path)
    ///   - userDefaults: Shared Memory for the exchange of dirty objects
    ///   - remoteSecretManager: Implementation to manage normal or encrypted database
    public convenience init(
        appGroupID: String,
        userDefaults: UserDefaults,
        remoteSecretManager: RemoteSecretManagerProtocol
    ) {
        let localDatabaseManager = DatabaseManager(
            appGroupID: appGroupID,
            remoteSecretManager: remoteSecretManager
        )

        self.init(
            databaseManager: localDatabaseManager,
            dirtyObjectManager: DirtyObjectManager(
                databaseManager: localDatabaseManager,
                userDefaults: userDefaults
            ),
            remoteSecretManager: remoteSecretManager
        )
    }

    required init(
        databaseManager: DatabaseManagerProtocol,
        dirtyObjectManager: DirtyObjectManager,
        remoteSecretManager: RemoteSecretManagerProtocol
    ) {
        self.databaseManager = databaseManager
        self.dirtyObjectManager = dirtyObjectManager
        self.remoteSecretManager = remoteSecretManager

        EntityCryptoManager.shared.setRemoteSecretManager(self.remoteSecretManager)
    }

    public let databaseManager: DatabaseManagerProtocol
    public let dirtyObjectManager: DirtyObjectManager

    /// For database access on the main thread
    public lazy var entityManager = EntityManager(
        databaseContext: self.databaseManager.databaseContext(),
        isRemoteSecretEnabled: remoteSecretManager.isRemoteSecretEnabled
    )

    /// For database access on a background thread
    public lazy var backgroundEntityManager = EntityManager(
        databaseContext: self.databaseManager.databaseContext(withChildContextForBackgroundProcess: true),
        isRemoteSecretEnabled: remoteSecretManager.isRemoteSecretEnabled
    )

    public func entityFetcher(with managedDatabaseContext: ThreemaManagedObjectContext) -> EntityFetcher {
        EntityFetcher(managedObjectContext: managedDatabaseContext)
    }
}
