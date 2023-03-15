//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class ContactTests: XCTestCase {

    var dbMainCnx: DatabaseContext!
    var dbPreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbPreparer = DatabasePreparer(context: mainCnx)
    }

    func testSaveAndImplicitReload() throws {
        let expectedIdentity = "MEMBER01"
        let expectedPublicKey = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoPubKeySize))!

        // Setup initial contact entity in DB

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity,
                verificationLevel: kVerificationLevelUnverified
            )
            contactEntity.publicNickname = "fritzberg"
            contactEntity.firstName = "Fritz"
            contactEntity.lastName = "Berg"
            contactEntity.state = NSNumber(integerLiteral: kStateInactive)
            contactEntity.workContact = NSNumber(booleanLiteral: true)
        }

        let contact = Contact(contactEntity: contactEntity)

        // Check contact properties before changing

        XCTAssertEqual(expectedIdentity, contact.identity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)
        XCTAssertEqual("fritzberg", contact.publicNickname)
        XCTAssertEqual("Fritz", contact.firstName)
        XCTAssertEqual("Berg", contact.lastName)
        XCTAssertEqual(kStateInactive, contact.state)
        XCTAssertTrue(contact.isWorkContact)

        // Change contact entity properties in DB

        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: MyIdentityStoreMock())
        entityManager.performSyncBlockAndSafe {
            contactEntity.firstName = "Fritzli"
            contactEntity.lastName = "Bergli"
            contactEntity.publicNickname = "fritzlibergli"
            contactEntity.verificationLevel = NSNumber(integerLiteral: kVerificationLevelServerVerified)
            contactEntity.state = NSNumber(integerLiteral: kStateActive)
            contactEntity.workContact = NSNumber(booleanLiteral: false)
        }

        // Check changed contact properties

        XCTAssertEqual(expectedIdentity, contactEntity.identity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)
        XCTAssertEqual("fritzlibergli", contact.publicNickname)
        XCTAssertEqual("Fritzli", contact.firstName)
        XCTAssertEqual("Bergli", contact.lastName)
        XCTAssertEqual(kStateActive, contact.state)
        XCTAssertFalse(contact.isWorkContact)
    }
}
