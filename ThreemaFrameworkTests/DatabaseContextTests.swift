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

import XCTest
@testable import ThreemaFramework

final class DatabaseContextTests: XCTestCase {
   
    // This tests the automaticallyMergesChangesFromParent of the private CoreData context
    func testMainContextMergesChangesToPrivateContext() async throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, dbMainCnx, dbBackgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        
        let databaseContext = DatabaseContext(
            mainContext: dbMainCnx,
            backgroundContext: nil
        )
        
        let databaseBGContext = DatabaseContext(
            mainContext: dbMainCnx,
            backgroundContext: dbBackgroundCnx
        )
        
        let entityManager = EntityManager(databaseContext: databaseContext)
        let entityManagerBg = EntityManager(databaseContext: databaseBGContext)
        let expectation = expectation(description: "changed")
        
        // 1. Create new contact
        await entityManager.performSave {
            let contact = entityManager.entityCreator.contact()!
            contact.publicKey = MockData.generatePublicKey()
            contact.verificationLevel = 1
            contact.identity = "ECHOECHO"
        }

        // 2. Load Contact on BG
        try await entityManagerBg.perform {
            let contact = try XCTUnwrap(
                entityManagerBg.entityFetcher
                    .contact(for: "ECHOECHO")
            )
            XCTAssertNotNil(contact)
            XCTAssertNil(contact.firstName)
            // 2.1 Detach and wait for concurrent change
            Task.detached {
                try await Task.sleep(seconds: 1)
                // 4. Check name did change
                XCTAssertNotNil(contact.firstName)
                expectation.fulfill()
            }
        }
        // 3. Change name
        try await entityManager.performSave {
            let contact = try XCTUnwrap(
                entityManager.entityFetcher
                    .contact(for: "ECHOECHO")
            )
            XCTAssertNotNil(contact)
            contact.firstName = "echo"
        }
        
        await fulfillment(of: [expectation])
    }
}
