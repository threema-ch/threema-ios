import RemoteSecretProtocolTestHelper
import ThreemaEssentials

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
        let databasePreparer = testDatabase.preparer
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
        let databasePreparer = testDatabase.preparer
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
        let databasePreparer = testDatabase.preparer
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
        let databasePreparer = testDatabase.preparer
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

    func testSolicitedContactConversationWithLastUpdate() {
        // Setup
        let databasePreparer = testDatabase.preparer
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        databasePreparer.save {
            let contact = databasePreparer.createContact(identity: contactIdentity.rawValue)
            let conversation = databasePreparer.createConversation(contactEntity: contact)
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

    func testSolicitedContactConversationWithLastUpdateInactiveContact() {
        // Setup
        let databasePreparer = testDatabase.preparer
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                identity: contactIdentity.rawValue,
                state: .inactive
            )

            let conversation = databasePreparer.createConversation(contactEntity: contact)
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

    func testSolicitedContactConversationWithLastUpdateInvalidContact() {
        // Setup
        let databasePreparer = testDatabase.preparer
        let contactIdentity = ThreemaIdentity("AAAAAAAA")
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                identity: contactIdentity.rawValue,
                state: .invalid
            )

            let conversation = databasePreparer.createConversation()
            conversation.contact = contact
            conversation.lastUpdate = .now
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // This contact should not appear in solicited contacts
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactActiveGroup() throws {
        // Setup
        let databasePreparer = testDatabase.preparer

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

            databasePreparer.createGroup(
                groupID: BytesUtility.generateGroupID(),
                groupCreatorIdentity: creatorIdentity.rawValue,
                members: memberIdentities.map(\.rawValue)
            )
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.rawValue)).isEmpty)
    }

    func testSolicitedContactActiveOwnGroup() throws {
        // Setup
        let databasePreparer = testDatabase.preparer
        let myIdentity = "TESTERID"
        let memberIdentities = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        try databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }

            databasePreparer.createGroup(
                groupID: BytesUtility.generateGroupID(),
                groupCreatorIdentity: myIdentity,
                members: memberIdentities.map(\.rawValue)
            )
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        XCTAssertEqual(memberIdentities.count, solicitedContacts.count)
        XCTAssertTrue(solicitedContacts.subtracting(memberIdentities.map(\.rawValue)).isEmpty)
    }

    // Requested Sync state doesn't seem to be used anymore. Skip

    func testSolicitedContactLeftGroup() throws {
        // Setup
        let databasePreparer = testDatabase.preparer

        let creatorIdentity = ThreemaIdentity("CREATOR1")
        let memberIdentities = [
            creatorIdentity,
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        try databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }

            let (_, group, _) = databasePreparer.createGroup(
                groupID: BytesUtility.generateGroupID(),
                groupCreatorIdentity: creatorIdentity.rawValue,
                members: memberIdentities.map(\.rawValue)
            )

            group.state = 2
        }

        // Run

        let entityFetcher = testDatabase.entityManager.entityFetcher
        let solicitedContacts = entityFetcher.solicitedContactIdentities()

        //  Validate

        // Closed group members should not be included
        XCTAssertEqual(0, solicitedContacts.count)
    }

    func testSolicitedContactForcedLeftGroup() throws {
        // Setup
        let databasePreparer = testDatabase.preparer

        let creatorIdentity = ThreemaIdentity("CREATOR1")
        let memberIdentities = [
            creatorIdentity,
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
            ThreemaIdentity("MEMBER04"),
        ]

        try databasePreparer.save {
            for memberIdentity in memberIdentities {
                databasePreparer.createContact(identity: memberIdentity.rawValue)
            }

            let (_, group, _) = databasePreparer.createGroup(
                groupID: BytesUtility.generateGroupID(),
                groupCreatorIdentity: creatorIdentity.rawValue,
                members: memberIdentities.map(\.rawValue)
            )

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
        let databasePreparer = testDatabase.preparer
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
        databasePreparer.createGroup(
            groupID: BytesUtility.generateGroupID(),
            groupCreatorIdentity: creator1.rawValue,
            members: members1.map(\.rawValue)
        )
        expectedIdentities.insert(creator1)
        expectedIdentities = expectedIdentities.union(members1)

        // Group 2: Normal
        let creator2 = identities[5]
        let members2 = Array(identities[4..<30])
        databasePreparer.createGroup(
            groupID: BytesUtility.generateGroupID(),
            groupCreatorIdentity: creator2.rawValue,
            members: members2.map(\.rawValue)
        )
        expectedIdentities.insert(creator2)
        expectedIdentities = expectedIdentities.union(members2)

        // Group 3: Left
        let creator3 = identities[10]
        let members3 = Array(identities[10..<40])
        let (_, group3, _) = databasePreparer.createGroup(
            groupID: BytesUtility.generateGroupID(),
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
    
    // MARK: - Test dateOfOldestContentMessage
    
    func testNoOldestMessageDate() {
        // Setup
        let conversationEntity = testDatabase.preparer.createConversation()
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let oldestMessageDate = entityFetcher.dateOfOldestContentMessage(in: conversationEntity)
        
        // Validate
        
        XCTAssertNil(oldestMessageDate)
    }
    
    func testOneOldestMessageDate() {
        // Setup
        let expectedOldestMessageDate: Date = .now
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        testDatabase.preparer.createTextMessage(
            conversation: conversationEntity,
            date: expectedOldestMessageDate,
            isOwn: true,
            sender: nil,
            remoteSentDate: nil
        )
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let actualOldestMessageDate = entityFetcher.dateOfOldestContentMessage(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(expectedOldestMessageDate, actualOldestMessageDate)
    }
    
    func testOldestMessageDate() {
        // Setup
        let numberOfMessage = 100
        let expectedOldestMessageDate: Date = .now.addingTimeInterval(-100_000 * Double(numberOfMessage))
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for messageNumber in 0..<numberOfMessage {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                date: expectedOldestMessageDate.addingTimeInterval(Double(messageNumber) * 60 * 60),
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let actualOldestMessageDate = entityFetcher.dateOfOldestContentMessage(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(expectedOldestMessageDate, actualOldestMessageDate)
    }
    
    func testContentAndNotContentOldestContentMessageDate() {
        // Setup
        let oldestSystemMessageDate: Date = .now.addingTimeInterval(-60 * 60 * 20)
        let oldestTextMessageDate: Date = .now
        
        for systemMessageEntityType in SystemMessageEntity.SystemMessageEntityType.allCases {
            let conversationEntity = testDatabase.preparer.createConversation()
            
            testDatabase.preparer.createSystemMessage(
                conversation: conversationEntity,
                type: systemMessageEntityType,
                date: oldestSystemMessageDate
            )
            
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                date: oldestTextMessageDate,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            
            // Run
            
            let entityFetcher = testDatabase.entityManager.entityFetcher
            let actualOldestMessageDate = entityFetcher.dateOfOldestContentMessage(in: conversationEntity)
            
            // Validate
            
            if SystemMessageEntity.SystemMessageEntityType.contentTypes.contains(systemMessageEntityType) {
                XCTAssertEqual(oldestSystemMessageDate, actualOldestMessageDate)
            }
            else {
                XCTAssertEqual(oldestTextMessageDate, actualOldestMessageDate)
            }
        }
    }
    
    // MARK: - Test nonSystemMessagesCount
    
    func testNoMessageNonSystemMessagesCount() {
        // Setup
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let nonSystemMessagesCount = entityFetcher.nonSystemMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(0, nonSystemMessagesCount)
    }
    
    func testJustSystemMessagesNonSystemMessagesCount() {
        // Setup
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for systemMessageEntityType in SystemMessageEntity.SystemMessageEntityType.allCases {
            testDatabase.preparer.createSystemMessage(
                conversation: conversationEntity,
                type: systemMessageEntityType
            )
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let nonSystemMessagesCount = entityFetcher.nonSystemMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(0, nonSystemMessagesCount)
    }
    
    func testMixOfSystemAndNonSystemMessagesNonSystemMessagesCount() {
        // Setup
        
        let expectedNumberOfNonSystemMessages = 100
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for _ in 0..<(expectedNumberOfNonSystemMessages / 2) {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        for systemMessageEntityType in SystemMessageEntity.SystemMessageEntityType.allCases {
            testDatabase.preparer.createSystemMessage(
                conversation: conversationEntity,
                type: systemMessageEntityType
            )
        }
        
        for _ in 0..<(expectedNumberOfNonSystemMessages / 2) {
            testDatabase.preparer.createFileMessageEntity(conversation: conversationEntity)
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let nonSystemMessagesCount = entityFetcher.nonSystemMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(expectedNumberOfNonSystemMessages, nonSystemMessagesCount)
    }
    
    // MARK: - Test outgoingContentMessagesCount
    
    func testNoMessagesOutgoingMessagesCount() {
        // Setup
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let outgoingMessagesCount = entityFetcher.outgoingContentMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(0, outgoingMessagesCount)
    }
    
    func testNoOutgoingMessagesOutgoingMessagesCount() {
        // Setup
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for _ in 0..<100 {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // This should not matter for this test
                remoteSentDate: nil // This should not matter for this test
            )
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let outgoingMessagesCount = entityFetcher.outgoingContentMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(0, outgoingMessagesCount)
    }
    
    func testFSSessionMessagesShouldNotCountAsOutgoingMessagesCount() {
        // Setup
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        testDatabase.preparer.createTextMessage(
            conversation: conversationEntity,
            isOwn: false,
            sender: nil, // This should not matter for this test
            remoteSentDate: nil // This should not matter for this test
        )
        
        testDatabase.preparer.createSystemMessage(
            conversation: conversationEntity,
            type: .fsSessionEstablished
        )
        
        // It is not clear if such message even exist, but just to be sure we test for system messages that are not
        // marked as outgoing
        let systemMessage = testDatabase.preparer.createSystemMessage(
            conversation: conversationEntity,
            type: .fsSessionReset
        )
        systemMessage.isOwn = false
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let outgoingMessagesCount = entityFetcher.outgoingContentMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(0, outgoingMessagesCount)
    }

    func testOutgoingMessagesCount() {
        // Setup
        
        let expectedNumberOfOutgoingMessages = 150
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for _ in 0..<(expectedNumberOfOutgoingMessages / 2) {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        for _ in 0..<100 {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // This should not matter for this test
                remoteSentDate: nil // This should not matter for this test
            )
        }
        
        for _ in 0..<(expectedNumberOfOutgoingMessages / 2) {
            testDatabase.preparer.createFileMessageEntity(conversation: conversationEntity, isOwn: true)
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let outgoingMessagesCount = entityFetcher.outgoingContentMessagesCount(in: conversationEntity)
        
        // Validate
        
        XCTAssertEqual(expectedNumberOfOutgoingMessages, outgoingMessagesCount)
    }
    
    func testAllSystemMessagesOutgoingContentMessagesCount() {
        // Setup
        
        let systemMessagesCountingAsContentMessagesCount = SystemMessageEntity.SystemMessageEntityType.contentTypes.count
        
        let conversationEntity = testDatabase.preparer.createConversation()
        
        for systemMessageEntityType in SystemMessageEntity.SystemMessageEntityType.allCases {
            testDatabase.preparer.createSystemMessage(conversation: conversationEntity, type: systemMessageEntityType)
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let outgoingMessagesCount = entityFetcher.outgoingContentMessagesCount(in: conversationEntity)
        
        XCTAssertEqual(systemMessagesCountingAsContentMessagesCount, outgoingMessagesCount)
    }
    
    // MARK: - isInNotLeftGroup
    
    func testIsInNotLeftGroupWithoutAnyGroups() throws {
        // Setup
        
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        let testContactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)

        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let isInNotLeftGroup = entityFetcher.isInNotLeftGroup(contact: testContactEntity)
        
        // Assert
        
        XCTAssertFalse(isInNotLeftGroup)
    }
    
    func testIsInNotLeftGroupWithOnlyLeftGroups() throws {
        // Setup
        
        let numberOfGroupsFromEachLeftState = 100
        
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        let testContactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        
        let creatorIdentity = try ThreemaIdentity(identity: "CREATOR1")
        let memberIdentities = try [
            creatorIdentity,
            testIdentity,
            ThreemaIdentity(identity: "MEMBER01"),
            ThreemaIdentity(identity: "MEMBER02"),
            ThreemaIdentity(identity: "MEMBER03"),
            ThreemaIdentity(identity: "MEMBER04"),
        ]
        
        for _ in 0..<numberOfGroupsFromEachLeftState {
            for groupState in [GroupEntity.GroupState.active, .requestedSync] {
                let (_, groupEntity, _) = testDatabase.preparer.createGroup(
                    groupCreatorIdentity: creatorIdentity.rawValue,
                    members: memberIdentities.map(\.rawValue)
                )
                groupEntity.state = groupState.rawValue as NSNumber
            }
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let isInNotLeftGroup = entityFetcher.isInNotLeftGroup(contact: testContactEntity)
        
        // Assert
        
        XCTAssertTrue(isInNotLeftGroup)
    }
    
    func testIsInNotLeftGroup() throws {
        // Setup
        
        let numberOfGroupsFromEachState = 100
        
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        let testContactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        
        let creatorIdentity = try ThreemaIdentity(identity: "CREATOR1")
        let memberIdentities = try [
            creatorIdentity,
            testIdentity,
            ThreemaIdentity(identity: "MEMBER01"),
            ThreemaIdentity(identity: "MEMBER02"),
            ThreemaIdentity(identity: "MEMBER03"),
            ThreemaIdentity(identity: "MEMBER04"),
        ]
        
        for _ in 0..<numberOfGroupsFromEachState {
            for groupState in GroupEntity.GroupState.allCases {
                let (_, groupEntity, _) = testDatabase.preparer.createGroup(
                    groupCreatorIdentity: creatorIdentity.rawValue,
                    members: memberIdentities.map(\.rawValue)
                )
                groupEntity.state = groupState.rawValue as NSNumber
            }
        }
        
        // Run
        
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let isInNotLeftGroup = entityFetcher.isInNotLeftGroup(contact: testContactEntity)
        
        // Assert
        
        XCTAssertTrue(isInNotLeftGroup)
    }

    // MARK: - Measurements

    // The following two methods are just for basic performance evaluation and disabled by default

    func testAllContactsFetchingPerformance() {
        let numberOfContacts = 9000 // Up to 5 digits allowed

        let databasePreparer = testDatabase.preparer

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

        let databasePreparer = testDatabase.preparer

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
            let expectedMessageID = BytesUtility.generateMessageID()
            let expectedGroupMessageID = BytesUtility.generateMessageID()

            let testDatabaseLocal = TestDatabase(encrypted: testCase.isDBEncrypted)

            let databasePreparer = testDatabaseLocal.preparer
            databasePreparer.save {
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

                let (_, _, groupConversation) = databasePreparer.createGroup(
                    groupID: BytesUtility.generateGroupID(),
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
