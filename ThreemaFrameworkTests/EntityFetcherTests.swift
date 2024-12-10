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

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class EntityFetcherTests: XCTestCase {

    private var mainContext: NSManagedObjectContext!
    private var databaseMainContext: DatabaseContext!
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let persistentContext = DatabasePersistentContext.devNullContext()
        mainContext = persistentContext.mainContext
        databaseMainContext = DatabaseContext(mainContext: mainContext, backgroundContext: nil)
    }

    func testHasDuplicateContactsEmptyDB() {
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertFalse(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        XCTAssertNil(duplicates)
    }

    func testHasDuplicateContactsNo() {
        let databasePreparer = DatabasePreparer(context: mainContext)
        databasePreparer.save {
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(kNaClCryptoPubKeySize))!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
        }

        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertFalse(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        XCTAssertNil(duplicates)
    }

    func testHasDuplicateContactsYes() throws {
        let databasePreparer = DatabasePreparer(context: mainContext)
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

        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!

        var duplicates: NSSet?
        XCTAssertTrue(entityFetcher.hasDuplicateContacts(withDuplicateIdentities: &duplicates))
        let duplicatesResult = try XCTUnwrap(duplicates)
        XCTAssertEqual(2, duplicatesResult.count)
        XCTAssertTrue(duplicatesResult.contains("ECHOECHO"))
        XCTAssertTrue(duplicatesResult.contains("PUPSIDUP"))
    }
    
    // MARK: - Test allSolicitedContactIdentities
    
    func testSolicitedContactJustContact() {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        databasePreparer.save {
            databasePreparer.createContact(identity: "AAAAAAAA")
        }
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }
        
    func testSolicitedContactConversationWithNoLastUpdate() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let contact = databasePreparer.save {
            databasePreparer.createContact(identity: "AAAAAAAA")
        }
        
        let entityManager = EntityManager(databaseContext: databaseMainContext)
        _ = await entityManager.performSave {
            entityManager.conversation(forContact: contact, createIfNotExisting: true, setLastUpdate: false)
        }
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }
    
    func testSolicitedContactConversationWithLastUpdate() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(identity: contactIdentity.string)
        }
        
        let entityManager = EntityManager(databaseContext: databaseMainContext)
        _ = await entityManager.performSave {
            entityManager.conversation(forContact: contact, createIfNotExisting: true, setLastUpdate: true)
        }
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // This contact should appear in solicited contacts
        XCTAssertEqual(1, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.contains(contactIdentity.string))
    }

    func testSolicitedContactConversationWithLastUpdateInactiveContact() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(
                identity: contactIdentity.string,
                state: NSNumber(integerLiteral: kStateInactive)
            )
        }
        
        let entityManager = EntityManager(databaseContext: databaseMainContext)
        _ = await entityManager.performSave {
            entityManager.conversation(forContact: contact, createIfNotExisting: true, setLastUpdate: true)
        }
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // This contact should appear in solicited contacts
        XCTAssertEqual(1, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.contains(contactIdentity.string))
    }
    
    func testSolicitedContactConversationWithLastUpdateInvalidContact() async {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        let contact = databasePreparer.save {
            databasePreparer.createContact(
                identity: contactIdentity.string,
                state: NSNumber(integerLiteral: kStateInvalid)
            )
        }
        
        let entityManager = EntityManager(databaseContext: databaseMainContext)
        _ = await entityManager.performSave {
            entityManager.conversation(forContact: contact, createIfNotExisting: true, setLastUpdate: true)
        }
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactActiveGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        
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
                databasePreparer.createContact(identity: memberIdentity.string)
            }
        }
        
        _ = try await createGroup(creator: creatorIdentity, members: memberIdentities)
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.string)).isEmpty)
    }
    
    func testSolicitedContactActiveOwnGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let myIdentityStoreMock = MyIdentityStoreMock()
        
        let memberIdentities = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]
        
        databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.string)
            }
        }
        
        _ = try await createGroup(
            creator: ThreemaIdentity(myIdentityStoreMock.identity),
            members: memberIdentities,
            myIdentityStore: myIdentityStoreMock
        )
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.string)).isEmpty)
    }

    // Requested Sync state doesn't seem to be used anymore. Skip
    
    func testSolicitedContactLeftGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        
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
                databasePreparer.createContact(identity: memberIdentity.string)
            }
        }
        
        let (groupManager, groupIdentity) = try await createGroup(creator: creatorIdentity, members: memberIdentities)
        groupManager.leave(groupWith: groupIdentity, inform: .all)
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // Closed group members should not be included
        XCTAssertEqual(0, solicitedContacts.count)
    }
    
    func testSolicitedContactForcedLeftGroup() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        
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
                databasePreparer.createContact(identity: memberIdentity.string)
            }
        }
        
        let (groupManager, groupIdentity) = try await createGroup(creator: creatorIdentity, members: memberIdentities)
        
        // Remove my own identity to force leave
        let tempGroup = try await groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(memberIdentities.map(\.string))
        )
        let group = try XCTUnwrap(tempGroup)
        XCTAssertEqual(GroupEntity.GroupState.forcedLeft, group.state)
                
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        // Closed group members should not be included
        XCTAssertEqual(0, solicitedContacts.count)
    }
    
    func testSolicitedContactMultipleGroupsAndContacts() async throws {
        // Setup
        let databasePreparer = DatabasePreparer(context: mainContext)
        let entityManager = EntityManager(databaseContext: databaseMainContext)

        // Create some identities to use
        
        let numberOfIdentities = 100
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 8
        let identities = databasePreparer.save {
            (0..<numberOfIdentities).map { index in
                let identity = ThreemaIdentity(
                    numberFormatter.string(from: NSNumber(integerLiteral: index))!
                )
                
                databasePreparer.createContact(identity: identity.string)
                
                return identity
            }
        }
        
        var expectedIdentities = Set<ThreemaIdentity>()
        
        // Conversation 1: Normal
        let contact1 = identities[0]
        _ = await entityManager.performSave {
            entityManager.conversation(for: contact1.string, createIfNotExisting: true, setLastUpdate: true)
        }
        expectedIdentities.insert(contact1)

        // Conversation 2: Normal
        let contact2 = identities[numberOfIdentities - 1]
        _ = await entityManager.performSave {
            entityManager.conversation(for: contact2.string, createIfNotExisting: true, setLastUpdate: true)
        }
        expectedIdentities.insert(contact2)
        
        // Conversation 3: No last update
        let contact3 = identities[numberOfIdentities - 10]
        _ = await entityManager.performSave {
            entityManager.conversation(for: contact3.string, createIfNotExisting: true, setLastUpdate: false)
        }
        // This one should not appear in the resulting set (if they are not part of another group or 1:1 conversation)
        
        // Group 1: Normal
        let creator1 = identities[0]
        let members1 = Array(identities[0..<10])
        _ = try await createGroup(creator: creator1, members: members1)
        expectedIdentities.insert(creator1)
        expectedIdentities = expectedIdentities.union(members1)
        
        // Group 2: Normal
        let creator2 = identities[5]
        let members2 = Array(identities[4..<30])
        _ = try await createGroup(creator: creator2, members: members2)
        expectedIdentities.insert(creator2)
        expectedIdentities = expectedIdentities.union(members2)
        
        // Group 3: Left
        let creator3 = identities[10]
        let members3 = Array(identities[10..<40])
        let (groupManager3, groupIdentity3) = try await createGroup(creator: creator3, members: members3)
        groupManager3.leave(groupWith: groupIdentity3, inform: .all)
        // Theses should not appear in the resulting set (if they are not part of another group or 1:1 conversation)
        
        // Run
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        let solicitedContacts = entityFetcher.allSolicitedContactIdentities()
        
        //  Validate
        
        XCTAssertEqual(expectedIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(expectedIdentities.map(\.string)).isEmpty)
    }
    
    private func createGroup(
        creator: ThreemaIdentity,
        members: [ThreemaIdentity],
        myIdentityStore: MyIdentityStoreProtocol = MyIdentityStoreMock()
    ) async throws -> (GroupManagerProtocol, GroupIdentity) {
        let entityManager = EntityManager(databaseContext: databaseMainContext, myIdentityStore: myIdentityStore)
        let groupManager = GroupManager(
            myIdentityStore,
            ContactStoreMock(callOnCompletion: true),
            TaskManagerMock(),
            UserSettingsMock(),
            entityManager,
            GroupPhotoSenderMock()
        )
                
        let groupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: creator)
        
        _ = try await groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.string) + [myIdentityStore.identity])
        )
        
        return (groupManager, groupIdentity)
    }
    
    // MARK: - Measurements
    
    // The following two methods are just for basic performance evaluation and disabled by default
    
    func testAllContactsFetchingPerformance() {
        let numberOfContacts = 90000 // Up to 5 digits allowed
        
        let databasePreparer = DatabasePreparer(context: mainContext)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 5
        
        databasePreparer.save {
            for index in 0..<numberOfContacts {
                databasePreparer.createContact(identity: "ABC\(numberFormatter.string(from: NSNumber(value: index))!)")
            }
        }
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!

        measure {
            let allContacts = entityFetcher.allContacts() ?? [Any]()
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
        let numberOfContacts = 90000 // Up to 5 digits allowed
        
        let databasePreparer = DatabasePreparer(context: mainContext)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 5
        
        databasePreparer.save {
            for index in 0..<numberOfContacts {
                databasePreparer.createContact(identity: "ABC\(numberFormatter.string(from: NSNumber(value: index))!)")
            }
        }
        
        let entityFetcher = EntityFetcher(mainContext, myIdentityStore: MyIdentityStoreMock())!
        
        measure {
            let allContactIdentities = entityFetcher.allContactIdentities()
            XCTAssertEqual(numberOfContacts, allContactIdentities.count)
        }
    }
}

// MARK: - Async testing helper

extension GroupManagerProtocol {
    fileprivate func createOrUpdateDB(
        for groupIdentity: GroupIdentity,
        members: Set<String>
    ) async throws -> Group? {
        try await createOrUpdateDB(
            for: groupIdentity,
            members: members,
            systemMessageDate: nil,
            sourceCaller: .local
        )
    }
}
