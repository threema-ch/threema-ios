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

import Foundation
import RemoteSecretProtocolTestHelper
@testable import RemoteSecret
@testable import ThreemaFramework

struct TestDatabase {

    let context: DatabaseContext
    let entityManager: EntityManager

    let remoteSecretCryptoMock: RemoteSecretCryptoMock
    let remoteSecretManagerMock: RemoteSecretManagerMock

    init(encrypted: Bool = false, forBackgroundThread: Bool = false) {
        let (persistentStoreCoordinator, mainContext, backgroundContext) = DatabasePersistentContext.devNullContext(
            withChildContextForBackgroundProcess: forBackgroundThread,
            isRemoteSecretEnabled: encrypted
        )

        self.context =
            if !forBackgroundThread {
                DatabaseContext(mainContext: mainContext)
            }
            else {
                DatabaseContext(mainContext: mainContext, backgroundContext: backgroundContext)
            }

        let remoteSecretCrypto = try! RemoteSecretCrypto(
            remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        )
        self.remoteSecretCryptoMock = RemoteSecretCryptoMock(wrapped: remoteSecretCrypto)
        self.remoteSecretManagerMock = RemoteSecretManagerMock(
            isRemoteSecretEnabled: encrypted,
            crypto: remoteSecretCryptoMock
        )

        let databaseManagerMock = DatabaseManagerMock(
            persistentStoreCoordinator: persistentStoreCoordinator,
            databaseContext: context,
        )

        self.entityManager = PersistenceManager(
            databaseManager: databaseManagerMock,
            dirtyObjectManager: DirtyObjectManager(
                databaseManager: databaseManagerMock,
                userDefaults: UserDefaults()
            ),
            remoteSecretManager: remoteSecretManagerMock
        ).entityManager
    }
}
