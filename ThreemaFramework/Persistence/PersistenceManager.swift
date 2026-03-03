//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
