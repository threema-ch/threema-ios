//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

class CollectionContactTests: XCTestCase {
    
    var databaseCnx: DatabaseContext!
    var databasePreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        databaseCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainCnx)
    }
    
    func testSortedContacts() {
        
        var contacts = [Contact]()
        
        databasePreparer.save {
            let contact1 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC01",
                verificationLevel: 0
            )
            contact1.firstName = "Yeung"
            contacts.append(Contact(contactEntity: contact1))

            let contact2 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC02",
                verificationLevel: 0
            )
            contact2.publicNickname = "Yeung"
            contacts.append(Contact(contactEntity: contact2))

            let contact3 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC03",
                verificationLevel: 0
            )
            contact3.firstName = "Ye"
            contact3.lastName = "ung"
            contacts.append(Contact(contactEntity: contact3))

            let contact4 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC04",
                verificationLevel: 0
            )
            contacts.append(Contact(contactEntity: contact4))
            
            let contact5 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC05",
                verificationLevel: 0
            )
            contact5.lastName = "Yeung"
            contacts.append(Contact(contactEntity: contact5))

            let contact6 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC06",
                verificationLevel: 0
            )
            contacts.append(Contact(contactEntity: contact6))
            
            let contact7 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC07",
                verificationLevel: 0
            )
            contact7.firstName = "Ye"
            contact7.lastName = "un"
            contacts.append(Contact(contactEntity: contact7))

            let contact8 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC08",
                verificationLevel: 0
            )
            contact8.publicNickname = "Yeung"
            contacts.append(Contact(contactEntity: contact8))

            let contact9 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC09",
                verificationLevel: 0
            )
            contact9.firstName = "Yeung"
            contact9.lastName = "Yeung"
            contacts.append(Contact(contactEntity: contact9))

            let contact10 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC10",
                verificationLevel: 0
            )
            contact10.lastName = "Yeung"
            contacts.append(Contact(contactEntity: contact10))

            let contact11 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC11",
                verificationLevel: 0
            )
            contact11.firstName = "Yeung"
            contacts.append(Contact(contactEntity: contact11))

            let contact12 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC12",
                verificationLevel: 0
            )
            contact12.firstName = "Ye"
            contact12.lastName = "un"
            contacts.append(Contact(contactEntity: contact12))

            let contact13 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC13",
                verificationLevel: 0
            )
            contact13.firstName = "Yeung"
            contact13.lastName = "Yeung"
            contacts.append(Contact(contactEntity: contact13))

            let contact14 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC14",
                verificationLevel: 0
            )
            contact14.firstName = "Yeu"
            contact14.lastName = "ng"
            contacts.append(Contact(contactEntity: contact14))
        }
        
        let userSettings = UserSettingsMock()
        
        // Run first name order
        
        let sortedContactsFirstName = contacts.sorted(with: userSettings)

        // Validate

        let expectedIDOrderFirstName = [
            "CONTAC07", // Ye un
            "CONTAC12", // Ye un
            "CONTAC03", // Ye ung
            "CONTAC14", // Yeu ng
            "CONTAC01", // Yeung (first)
            "CONTAC11", // Yeung (first)
            "CONTAC05", // Yeung (last)
            "CONTAC10", // Yeung (last)
            "CONTAC02", // Yeung (nick)
            "CONTAC08", // Yeung (nick)
            "CONTAC09", // Yeung Yeung
            "CONTAC13", // Yeung Yeung
            "CONTAC04", // CONTACT4
            "CONTAC06", // CONTACT6
        ]

        XCTAssertEqual(expectedIDOrderFirstName.count, sortedContactsFirstName.count)
        XCTAssertEqual(expectedIDOrderFirstName, sortedContactsFirstName.map(\.identity.string))

        // Run last name order

        userSettings.sortOrderFirstName = false
        let sortedContactsLastName = contacts.sorted(with: userSettings)

        // Validate

        let expectedIDOrderLastName = [
            "CONTAC14", // ng Yeu
            "CONTAC07", // un Ye
            "CONTAC12", // un Ye
            "CONTAC03", // ung Ye
            "CONTAC05", // Yeung (last)
            "CONTAC10", // Yeung (last)
            "CONTAC01", // Yeung (first)
            "CONTAC11", // Yeung (first)
            "CONTAC02", // Yeung (nick)
            "CONTAC08", // Yeung (nick)
            "CONTAC09", // Yeung Yeung
            "CONTAC13", // Yeung Yeung
            "CONTAC04", // CONTACT4
            "CONTAC06", // CONTACT6
        ]

        XCTAssertEqual(expectedIDOrderLastName.count, sortedContactsLastName.count)
        XCTAssertEqual(expectedIDOrderLastName, sortedContactsLastName.map(\.identity.string))
    }
    
    func testSortedContactsWithSpecialCharacters() {
        var contacts = [Contact]()
        
        databasePreparer.save {
            let contact1 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC01",
                verificationLevel: 0
            )
            contact1.lastName = "Müller"
            contacts.append(Contact(contactEntity: contact1))

            let contact2 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC02",
                verificationLevel: 0
            )
            contact2.lastName = "Muller"
            contacts.append(Contact(contactEntity: contact2))

            let contact3 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC03",
                verificationLevel: 0
            )
            contact3.lastName = "ábenā"
            contacts.append(Contact(contactEntity: contact3))

            let contact4 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC04",
                verificationLevel: 0
            )
            contact4.lastName = "Abena"
            contacts.append(Contact(contactEntity: contact4))

            let contact5 = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "CONTAC05",
                verificationLevel: 0
            )
            contact5.lastName = "Mueller"
            contacts.append(Contact(contactEntity: contact5))
        }
        
        let userSettings = UserSettingsMock()
        
        // Run first name order
        
        let sortedContactsFirstName = contacts.sorted(with: userSettings)

        // Validate

        let expectedIDOrderFirstName = [
            "CONTAC04", // Abena
            "CONTAC03", // ábenā
            "CONTAC05", // Mueller
            "CONTAC02", // Muller
            "CONTAC01", // Müller
        ]

        XCTAssertEqual(expectedIDOrderFirstName.count, sortedContactsFirstName.count)
        XCTAssertEqual(expectedIDOrderFirstName, sortedContactsFirstName.map(\.identity.string))
    }
}
