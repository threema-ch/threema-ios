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

import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

final class NonceEntityTests: XCTestCase {
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let nonce = MockData.generateMessageNonce()
        let entityManager = testDatabase.entityManager

        // Act
        let nonceEntity = entityManager.performAndWaitSave {
            NonceEntity(context: testDatabase.context.main, nonce: nonce)
        }

        let fetchedNonceEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: nonceEntity.objectID) as? NonceEntity
        )
        
        // Assert
        XCTAssertEqual(nonce, fetchedNonceEntity.nonce)
    }
}
