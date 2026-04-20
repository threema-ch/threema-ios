import RemoteSecretProtocolTestHelper
import ThreemaEssentials
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
        let testDatabase = TestDatabase(encrypted: encrypted)
        let entityManager = testDatabase.entityManager

        let active = true
        let browserName = "Test Browser Name"
        let browserVersion: Int32 = 1
        let initiatorPermanentPublicKey = BytesUtility.generatePublicKey()
        let initiatorPermanentPublicKeyHash = "HASH"
        let lastConnection = Date.now
        let name = "Test name"
        let permanent = true
        let privateKey = BytesUtility.generatePublicKey()
        let saltyRTCHost = "HOST"
        let saltyRTCPort = 25565
        let selfHosted = false
        let serverPermanentPublicKey = BytesUtility.generatePublicKey()
        let version: Int32 = 2

        // Act
        let webClientSessionEntity = entityManager.performAndWaitSave {
            WebClientSessionEntity(
                context: testDatabase.context.main,
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
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 11)

            // Test faulting
            testDatabase.context.main.refresh(fetchedWebClientSessionEntity, mergeChanges: false)

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

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 11)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 11)
        }
        else {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 0)
        }
    }

    func testCreationMinimal() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let initiatorPermanentPublicKey = BytesUtility.generatePublicKey()
        let permanent = true
        let saltyRTCHost = "HOST"
        let saltyRTCPort = 25565
        let selfHosted = false
        let serverPermanentPublicKey = BytesUtility.generatePublicKey()
        
        // Act
        let webClientSessionEntity = entityManager.performAndWaitSave {
            WebClientSessionEntity(
                context: testDatabase.context.main,
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
