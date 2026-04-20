import Foundation
import RemoteSecretProtocolTestHelper
@testable import RemoteSecret
@testable import ThreemaFramework

struct TestDatabase {
    // Just the main context without a private context
    let context: DatabaseContextProtocol
    let backgroundContext: DatabaseContextProtocol

    let preparer: TestDatabasePreparer
    let backgroundPreparer: TestDatabasePreparer

    let entityManager: EntityManager
    let backgroundEntityManager: EntityManager

    let remoteSecretCryptoMock: RemoteSecretCryptoMock
    let remoteSecretManagerMock: RemoteSecretManagerMock
    let databaseManagerMock: DatabaseManagerMock

    init(encrypted: Bool = false) {
        self.context = DatabaseContextMock(isRemoteSecretEnabled: encrypted)
        self.backgroundContext = DatabaseContextMock(mainContext: context.main)

        self.preparer = TestDatabasePreparer(context: context.main)
        self.backgroundPreparer = TestDatabasePreparer(context: backgroundContext.current)

        let remoteSecretCrypto = try! RemoteSecretCrypto(
            remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        )
        self.remoteSecretCryptoMock = RemoteSecretCryptoMock(wrapped: remoteSecretCrypto)
        self.remoteSecretManagerMock = RemoteSecretManagerMock(
            isRemoteSecretEnabled: encrypted,
            crypto: remoteSecretCryptoMock
        )

        self.databaseManagerMock = DatabaseManagerMock(
            persistentStoreCoordinator: context.main.persistentStoreCoordinator!,
            databaseContext: context,
            backgroundDatabaseContext: backgroundContext
        )

        let persistenceManager = PersistenceManager(
            databaseManager: databaseManagerMock,
            dirtyObjectManager: DirtyObjectManager(
                databaseManager: databaseManagerMock,
                userDefaults: UserDefaults()
            ),
            remoteSecretManager: remoteSecretManagerMock
        )

        self.entityManager = persistenceManager.entityManager
        self.backgroundEntityManager = persistenceManager.backgroundEntityManager
    }
}
