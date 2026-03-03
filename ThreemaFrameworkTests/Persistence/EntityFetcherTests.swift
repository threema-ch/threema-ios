//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentials
import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

final class EntityFetcherTests: XCTestCase {

    private var testDatabase: TestDatabase!

    override func setUpWithError() throws {
        testDatabase = TestDatabase()
    }

    func testHasDuplicateContactsEmptyDB() {
        let entityFetcher = testDatabase.entityManager.entityFetcher

        XCTAssertNil(entityFetcher.duplicateContactIdentities())
    }

    func testHasDuplicateContactsNo() {
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        databasePreparer.save {
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!,
                identity: "ECHOECHO"
            )
        }

        let entityFetcher = testDatabase.entityManager.entityFetcher

        XCTAssertNil(entityFetcher.duplicateContactIdentities())
    }

    func testHasDuplicateContactsYes() throws {
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        databasePreparer.save {
            let publicKey1 = BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!
            let identity1 = "ECHOECHO"
            for _ in 0...1 {
                databasePreparer.createContact(
                    publicKey: publicKey1,
                    identity: identity1
                )
            }

            let publicKey2 = BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!
            let identity2 = "PUPSIDUP"
            for _ in 0...2 {
                databasePreparer.createContact(
                    publicKey: publicKey2,
                    identity: identity2
                )
            }
        }

        let entityFetcher = testDatabase.entityManager.entityFetcher

        let duplicates = entityFetcher.duplicateContactIdentities()
        let duplicatesResult = try XCTUnwrap(duplicates)
        XCTAssertEqual(2, duplicatesResult.count)
        XCTAssertTrue(duplicatesResult.contains("ECHOECHO"))
        XCTAssertTrue(duplicatesResult.contains("PUPSIDUP"))
    }

    // MARK: - Test allSolicitedContactIdentities

    func testSolicitedContactJustContact() {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        databasePreparer.save {
            databasePreparer.createContact(identity: "AAAAAAAA")
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher

        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactConversationWithNoLastUpdate() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let contact = databasePreparer.save {
            databasePreparer.createContact(identity: "AAAAAAAA")
        }

        let entityManager = testDatabase.entityManager
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact
            conversation.lastUpdate = nil
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactConversationWithLastUpdate() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(identity: contactIdentity.rawValue)
        }

        let entityManager = testDatabase.entityManager
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact
            conversation.lastUpdate = .now
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should appear in solicited contacts
        XCTAssertEqual(1, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.contains(contactIdentity.rawValue))
    }

    func testSolicitedContactConversationWithLastUpdateInactiveContact() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(
                identity: contactIdentity.rawValue,
                state: .inactive
            )
        }

        let entityManager = testDatabase.entityManager
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact
            conversation.lastUpdate = .now
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should appear in solicited contacts
        XCTAssertEqual(1, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.contains(contactIdentity.rawValue))
    }

    func testSolicitedContactConversationWithLastUpdateInvalidContact() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(
                identity: contactIdentity.rawValue,
                state: .invalid
            )
        }

        let entityManager = testDatabase.entityManager
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact
            conversation.lastUpdate = .now
        }

        // Run

        let entityFetcher = entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactActiveGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)

        let creatorIdentity = ThreemaIdentity("CREATOR1")
        let memberIdentities = [
            creatorIdentity,
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }
        }

        _ = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creatorIdentity.rawValue,
            members: memberIdentities.map(\.rawValue)
        )

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.rawValue)).isEmpty)
    }

    func testSolicitedContactActiveOwnGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let myIdentity = "TESTERID"
        let memberIdentities = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }
        }

        _ = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: myIdentity,
            members: memberIdentities.map(\.rawValue)
        )

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.rawValue)).isEmpty)
    }

    // Requested Sync state doesn't seem to be used anymore. Skip

    func testSolicitedContactLeftGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)

        let creatorIdentity = ThreemaIdentity("CREATOR1")
        let memberIdentities = [
            creatorIdentity,
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }
        }

        let (_, group, _) = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creatorIdentity.rawValue,
            members: memberIdentities.map(\.rawValue)
        )

        databasePreparer.save {
            group.state = 2
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // Closed group members should not be included
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactForcedLeftGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)

        let creatorIdentity = ThreemaIdentity("CREATOR1")
        let memberIdentities = [
            creatorIdentity,
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }
        }

        let (_, group, _) = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creatorIdentity.rawValue,
            members: memberIdentities.map(\.rawValue)
        )

        databasePreparer.save {
            group.state = 3
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // Closed group members should not be included
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactMultipleGroupsAndContacts() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)
        let entityManager = testDatabase.entityManager

        // Create some identities to use

        let numberOfIdentities = 100

        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 8
        let identities = databasePreparer.save {
            (0..<numberOfIdentities).map { index in
                let identity = ThreemaIdentity(
                    numberFormatter.string(from: NSNumber(integerLiteral: index))!
                )
                databasePreparer.createContact(identity: identity.rawValue)
                return identity
            }
        }

        var expectedIdentities = Set<ThreemaIdentity>()

        // Conversation 1: Normal
        let contact1 = identities[0]
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = entityManager.entityFetcher.contactEntity(for: contact1.rawValue)
            conversation.lastUpdate = .now
        }
        expectedIdentities.insert(contact1)

        // Conversation 2: Normal
        let contact2 = identities[numberOfIdentities - 1]
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = entityManager.entityFetcher.contactEntity(for: contact2.rawValue)
            conversation.lastUpdate = .now
        }
        expectedIdentities.insert(contact2)

        // Conversation 3: No last update
        let contact3 = identities[numberOfIdentities - 10]
        _ = await entityManager.performSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = entityManager.entityFetcher.contactEntity(for: contact3.rawValue)
            conversation.lastUpdate = nil
        }
        // This one should not appear in the resulting set (if they are not part of another group or 1:1 conversation)

        // Group 1: Normal
        let creator1 = identities[0]
        let members1 = Array(identities[0..<10])
        let _ = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creator1.rawValue,
            members: members1.map(\.rawValue)
        )
        expectedIdentities.insert(creator1)
        expectedIdentities = expectedIdentities.union(members1)

        // Group 2: Normal
        let creator2 = identities[5]
        let members2 = Array(identities[4..<30])
        let _ = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creator2.rawValue,
            members: members2.map(\.rawValue)
        )
        expectedIdentities.insert(creator2)
        expectedIdentities = expectedIdentities.union(members2)

        // Group 3: Left
        let creator3 = identities[10]
        let members3 = Array(identities[10..<40])
        let (_, group3, _) = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: creator3.rawValue,
            members: members3.map(\.rawValue)
        )
        databasePreparer.save {
            group3.state = 2
        }
        // Theses should not appear in the resulting set (if they are not part of another group or 1:1 conversation)

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        XCTAssertEqual(expectedIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(expectedIdentities.map(\.rawValue)).isEmpty)
    }

    // MARK: - Measurements

    // The following two methods are just for basic performance evaluation and disabled by default

    func testAllContactsFetchingPerformance() {
        let numberOfContacts = 9000 // Up to 5 digits allowed

        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)

        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 5

        databasePreparer.save {
            for index in 0..<numberOfContacts {
                databasePreparer.createContact(identity: "ABC\(numberFormatter.string(from: NSNumber(value: index))!)")
            }
        }

        let entityFetcher = testDatabase.entityManager.entityFetcher

        measure {
            let allContacts = entityFetcher.contactEntities() ?? [Any]()
            let allContactIdentities: [String] = allContacts.compactMap {
                guard let contact = $0 as? ContactEntity else {
                    return nil
                }

                return contact.identity
            }
            XCTAssertEqual(numberOfContacts, allContactIdentities.count)
        }
    }

    func testAllContactIdentitiesFetchingPerformance() {
        let numberOfContacts = 9000 // Up to 5 digits allowed

        let databasePreparer = DatabasePreparer(context: testDatabase.context.main)

        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 5

        databasePreparer.save {
            for index in 0..<numberOfContacts {
                databasePreparer.createContact(identity: "ABC\(numberFormatter.string(from: NSNumber(value: index))!)")
            }
        }

        let entityFetcher = testDatabase.entityManager.entityFetcher

        measure {
            let allContactIdentities = entityFetcher.contactIdentities()
            XCTAssertEqual(numberOfContacts, allContactIdentities.count)
        }
    }

    func testIsMessageDelivered() throws {
        let expectedSenderIdentity = "ECHOECHO"

        // Test case for message are delivered and not
        let testCases: [(isDBEncrypted: Bool, isDelivered: Bool)] = [
            (true, true),
            (true, false),
            (false, true),
            (false, false),
        ]

        for testCase in testCases {
            let expectedMessageID = MockData.generateMessageID()
            let expectedGroupMessageID = MockData.generateMessageID()

            let testDatabaseLocal = TestDatabase(encrypted: testCase.isDBEncrypted)

            let databasePreparer = DatabasePreparer(context: testDatabaseLocal.context.main)
            try databasePreparer.save {
                let contact = databasePreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!,
                    identity: expectedSenderIdentity,
                    verificationLevel: .unverified
                )

                let conversation = databasePreparer.createConversation(contactEntity: contact)

                // New 1-1 message
                databasePreparer.createTextMessage(
                    conversation: conversation,
                    delivered: testCase.isDelivered,
                    id: expectedMessageID,
                    isOwn: false,
                    sender: nil,
                    remoteSentDate: nil
                )

                let (_, _, groupConversation) = try databasePreparer.createGroup(
                    groupID: MockData.generateGroupID(),
                    groupCreatorIdentity: expectedSenderIdentity,
                    members: [expectedSenderIdentity]
                )

                // New group message
                databasePreparer.createTextMessage(
                    conversation: groupConversation,
                    delivered: testCase.isDelivered,
                    id: expectedGroupMessageID,
                    isOwn: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }

            let entityFetcher = testDatabaseLocal.entityManager.entityFetcher

            let isMessageDelivered = entityFetcher.isMessageDelivered(
                from: expectedSenderIdentity,
                with: expectedMessageID
            )

            XCTAssertEqual(isMessageDelivered, testCase.isDelivered)

            let isGroupMessageDelivered = entityFetcher.isMessageDelivered(
                from: expectedSenderIdentity,
                with: expectedGroupMessageID
            )

            XCTAssertEqual(isGroupMessageDelivered, testCase.isDelivered)
        }
    }
}
