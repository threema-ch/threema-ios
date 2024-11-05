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

final class GroupCallEntityTests: XCTestCase {
    
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
        let entityManager = EntityManager(databaseContext: dbContext)
        let gck = MockData.generateGCK()
        let protocolVersion = Int32(32)
        let sfuBaseURL = "fakeURL"
        let startMessageReceiveDate = Date.now
        
        // Act
        let groupCallEntity = try entityManager.performAndWaitSave {
            let groupCallEntity = try XCTUnwrap(entityManager.entityCreator.groupCallEntity())
            
            groupCallEntity.gck = gck
            groupCallEntity.protocolVersion = protocolVersion as NSNumber
            groupCallEntity.sfuBaseURL = sfuBaseURL
            groupCallEntity.startMessageReceiveDate = startMessageReceiveDate
            return groupCallEntity
        }

        let fetchedGroupCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupCallEntity.objectID) as? GroupCallEntity
        )
        
        // Assert
        let fetchedProtocolVersion = try XCTUnwrap(fetchedGroupCallEntity.protocolVersion)
        XCTAssertEqual(gck, fetchedGroupCallEntity.gck)
        XCTAssertEqual(protocolVersion, Int32(truncating: fetchedProtocolVersion))
        XCTAssertEqual(sfuBaseURL, fetchedGroupCallEntity.sfuBaseURL)
        XCTAssertEqual(startMessageReceiveDate, fetchedGroupCallEntity.startMessageReceiveDate)
    }
}
