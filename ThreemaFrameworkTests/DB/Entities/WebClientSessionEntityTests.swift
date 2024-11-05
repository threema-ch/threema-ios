//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

final class WebClientSessionEntityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var dbContext: DatabaseContext!
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        dbContext = DatabaseContext(mainContext: managedObjectContext, backgroundContext: nil)
    }
    
    // MARK: - Tests
    
    func testCreation() throws {
        // Arrange
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
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        let webClientSessionEntity = try entityManager.performAndWaitSave {
            let webClientSessionEntity = try XCTUnwrap(entityManager.entityCreator.webClientSessionEntity())
            
            webClientSessionEntity.active = NSNumber(booleanLiteral: active)
            webClientSessionEntity.browserName = browserName
            webClientSessionEntity.browserVersion = browserVersion as NSNumber
            webClientSessionEntity.initiatorPermanentPublicKey = initiatorPermanentPublicKey
            webClientSessionEntity.initiatorPermanentPublicKeyHash = initiatorPermanentPublicKeyHash
            webClientSessionEntity.lastConnection = lastConnection
            webClientSessionEntity.name = name
            webClientSessionEntity.permanent = NSNumber(booleanLiteral: permanent)
            webClientSessionEntity.privateKey = privateKey
            webClientSessionEntity.saltyRTCHost = saltyRTCHost
            webClientSessionEntity.saltyRTCPort = saltyRTCPort as NSNumber
            webClientSessionEntity.selfHosted = NSNumber(booleanLiteral: selfHosted)
            webClientSessionEntity.serverPermanentPublicKey = serverPermanentPublicKey
            webClientSessionEntity.version = version as NSNumber
            
            return webClientSessionEntity
        }
        
        let fetchedWebClientSessionEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: webClientSessionEntity.objectID) as? WebClientSessionEntity
        )
        
        // Assert
        XCTAssertEqual(fetchedWebClientSessionEntity.active, NSNumber(booleanLiteral: active))
        XCTAssertEqual(fetchedWebClientSessionEntity.browserName, browserName)
        XCTAssertEqual(fetchedWebClientSessionEntity.browserVersion, browserVersion as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKey, initiatorPermanentPublicKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.initiatorPermanentPublicKeyHash, initiatorPermanentPublicKeyHash)
        XCTAssertEqual(fetchedWebClientSessionEntity.lastConnection, lastConnection)
        XCTAssertEqual(fetchedWebClientSessionEntity.name, name)
        XCTAssertEqual(fetchedWebClientSessionEntity.permanent, NSNumber(booleanLiteral: permanent))
        XCTAssertEqual(fetchedWebClientSessionEntity.privateKey, privateKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCHost, saltyRTCHost)
        XCTAssertEqual(fetchedWebClientSessionEntity.saltyRTCPort, saltyRTCPort as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.selfHosted, NSNumber(booleanLiteral: selfHosted))
        XCTAssertEqual(fetchedWebClientSessionEntity.serverPermanentPublicKey, serverPermanentPublicKey)
        XCTAssertEqual(fetchedWebClientSessionEntity.version, version as NSNumber)
        XCTAssertEqual(fetchedWebClientSessionEntity.active, webClientSessionEntity.active)
    }
}
