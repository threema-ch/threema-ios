//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import RemoteSecretProtocolTestHelper
import ThreemaEssentialsTestHelper
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class WebClientSessionEntityTests: XCTestCase {
    
    // MARK: - Tests
    
    func testCreationFull() throws {
        try creationTestFull(encrypted: false)
    }
    
    func testCreationEncrypted() throws {
        try creationTestFull(encrypted: true)
    }
    
    private func creationTestFull(encrypted: Bool) throws {
        // Arrange
        let (persistentStoreCoordinator, mainContext, backgroundContext) = DatabasePersistentContext.devNullContext(
            isRemoteSecretEnabled: encrypted
        )
        let dbContext = DatabaseContext(mainContext: mainContext, backgroundContext: backgroundContext)

        let remoteSecretCrypto = try RemoteSecretCrypto(
            remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        )
        let remoteSecretCryptoMock = RemoteSecretCryptoMock(wrapped: remoteSecretCrypto)
        let remoteSecretManagerMock = RemoteSecretManagerMock(
            isRemoteSecretEnabled: encrypted,
            crypto: remoteSecretCryptoMock
        )
        
        let databaseManagerMock = DatabaseManagerMock(
            persistentStoreCoordinator: persistentStoreCoordinator,
            databaseContext: dbContext,
        )

        let entityManager = PersistenceManager(
            databaseManager: databaseManagerMock,
            dirtyObjectManager: DirtyObjectManager(
                databaseManager: databaseManagerMock,
                userDefaults: UserDefaults()
            ),
            remoteSecretManager: remoteSecretManagerMock
        ).entityManager

        let active = true
        let browserName = "Test Browser Name"
        let browserVersion: Int32 = 1
        let initiatorPermanentPublicKey = MockData.generatePublicKey()
        let initiatorPermanentPublicKeyHash = "HASH"
        let lastConnection = Date.now
        let name = "Test name"
        let permanent = true
        let privateKey = MockData.generatePublicKey()
        let saltyRTCHost = "HOST"
        let saltyRTCPort = 25565
        let selfHosted = false
        let serverPermanentPublicKey = MockData.generatePublicKey()
        let version: Int32 = 2

        // Act
        let webClientSessionEntity = entityManager.performAndWaitSave {
            WebClientSessionEntity(
                context: dbContext.main,
                active: active,
                browserName: browserName,
                browserVersion: browserVersion,
                initiatorPermanentPublicKey: initiatorPermanentPublicKey,
                initiatorPermanentPublicKeyHash: initiatorPermanentPublicKeyHash,
                lastConnection: lastConnection,
                name: name,
                permanent: permanent,
                privateKey: privateKey,
                saltyRTCHost: saltyRTCHost,
                saltyRTCPort: Int64(saltyRTCPort),
                selfHosted: selfHosted,
                serverPermanentPublicKey: serverPermanentPublicKey,
                version: version
            )
        }
        
        let fetchedWebClientSessionEntity = try XCTUnwrap(
            entityManager.entityFetcher.existingObject(with: webClientSessionEntity.objectID) as? WebClientSessionEntity
        )
        
        // Assert
        XCTAssertEqual(fetchedWebClientSessionEntity.active, NSNumber(booleanLiteral: active))
        XCTAssertEqual(fetchedWebClientSessionEntity.browserName, browserName)
        XCTAssertEqual(fetchedWebClientSessionEntity.browserVersion, browserVersion as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKey, initiatorPermanentPublicKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKeyHash, initiatorPermanentPublicKeyHash)
        XCTAssertEqual(
            fetchedWebClientSessionEntity.lastConnection?.timeIntervalSince1970,
            lastConnection.timeIntervalSince1970
        )
        XCTAssertEqual(fetchedWebClientSessionEntity.name, name)
        XCTAssertEqual(fetchedWebClientSessionEntity.permanent, NSNumber(booleanLiteral: permanent))
        XCTAssertEqual(fetchedWebClientSessionEntity.privateKey, privateKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCHost, saltyRTCHost)
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCPort, saltyRTCPort as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.selfHosted, NSNumber(booleanLiteral: selfHosted))
        XCTAssertEqual(fetchedWebClientSessionEntity.serverPermanentPublicKey, serverPermanentPublicKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.version, version as NSNumber)

        if encrypted {
            XCTAssertEqual(remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(remoteSecretCryptoMock.encryptCalls, 11)

            // Test faulting
            mainContext.refresh(fetchedWebClientSessionEntity, mergeChanges: false)

            XCTAssertEqual(fetchedWebClientSessionEntity.active, NSNumber(booleanLiteral: active))
            XCTAssertEqual(fetchedWebClientSessionEntity.browserName, browserName)
            XCTAssertEqual(fetchedWebClientSessionEntity.browserVersion, browserVersion as NSNumber)
            XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKey, initiatorPermanentPublicKey)
            XCTAssertEqual(
                fetchedWebClientSessionEntity.lastConnection?.timeIntervalSince1970,
                lastConnection.timeIntervalSince1970
            )
            XCTAssertEqual(fetchedWebClientSessionEntity.name, name)
            XCTAssertEqual(fetchedWebClientSessionEntity.privateKey, privateKey)
            XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCHost, saltyRTCHost)
            XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCPort, saltyRTCPort as NSNumber)
            XCTAssertEqual(fetchedWebClientSessionEntity.selfHosted, NSNumber(booleanLiteral: selfHosted))
            XCTAssertEqual(fetchedWebClientSessionEntity.serverPermanentPublicKey, serverPermanentPublicKey)
            XCTAssertEqual(fetchedWebClientSessionEntity.version, version as NSNumber)

            XCTAssertEqual(remoteSecretCryptoMock.decryptCalls, 11)
            XCTAssertEqual(remoteSecretCryptoMock.encryptCalls, 11)
        }
        else {
            XCTAssertEqual(remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(remoteSecretCryptoMock.encryptCalls, 0)
        }
    }

    func testCreationMinimal() throws {
        // Arrange
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        let dbContext = DatabaseContext(mainContext: managedObjectContext, backgroundContext: nil)
        let entityManager = EntityManager(
            databaseContext: dbContext,
            isRemoteSecretEnabled: false
        )
        
        let initiatorPermanentPublicKey = MockData.generatePublicKey()
        let permanent = true
        let saltyRTCHost = "HOST"
        let saltyRTCPort = 25565
        let selfHosted = false
        let serverPermanentPublicKey = MockData.generatePublicKey()
        
        // Act
        let webClientSessionEntity = entityManager.performAndWaitSave {
            WebClientSessionEntity(
                context: dbContext.main,
                initiatorPermanentPublicKey: initiatorPermanentPublicKey,
                permanent: permanent,
                saltyRTCHost: saltyRTCHost,
                saltyRTCPort: Int64(saltyRTCPort),
                selfHosted: selfHosted,
                serverPermanentPublicKey: serverPermanentPublicKey
            )
        }
        
        let fetchedWebClientSessionEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: webClientSessionEntity.objectID) as? WebClientSessionEntity
        )
        
        // Assert
        XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKey, initiatorPermanentPublicKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.permanent, NSNumber(booleanLiteral: permanent))
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCHost, saltyRTCHost)
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCPort, saltyRTCPort as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.selfHosted, NSNumber(booleanLiteral: selfHosted))
        XCTAssertEqual(fetchedWebClientSessionEntity.serverPermanentPublicKey, serverPermanentPublicKey)
    }
}
