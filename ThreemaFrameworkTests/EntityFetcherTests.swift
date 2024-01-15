//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

final class EntityFetcherTests: XCTestCase {

    private var mainCnx: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let dbContext = DatabasePersistentContext.devNullContext()
        mainCnx = dbContext.mainContext
    }

    func testHasDuplicateContactsEmptyDB() {
        let entityFetcher = EntityFetcher(mainCnx, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertFalse(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        XCTAssertNil(duplicates)
    }

    func testHasDuplicateContactsNo() {
        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(kNaClCryptoPubKeySize))!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
        }

        let entityFetcher = EntityFetcher(mainCnx, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertFalse(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        XCTAssertNil(duplicates)
    }

    func testHasDuplicateContactsYes() throws {
        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey1 = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoPubKeySize))!
            let identity1 = "ECHOECHO"
            for _ in 0...1 {
                databasePreparer.createContact(
                    publicKey: publicKey1,
                    identity: identity1,
                    verificationLevel: 0
                )
            }

            let publicKey2 = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoPubKeySize))!
            let identity2 = "PUPSIDUP"
            for _ in 0...2 {
                databasePreparer.createContact(
                    publicKey: publicKey2,
                    identity: identity2,
                    verificationLevel: 0
                )
            }
        }

        let entityFetcher = EntityFetcher(mainCnx, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertTrue(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        let duplicatesResult = try XCTUnwrap(duplicates)
        XCTAssertEqual(2, duplicatesResult.count)
        XCTAssertTrue(duplicatesResult.contains("ECHOECHO"))
        XCTAssertTrue(duplicatesResult.contains("PUPSIDUP"))
    }
}
