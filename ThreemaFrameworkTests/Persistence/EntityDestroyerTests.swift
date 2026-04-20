import CoreData
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class EntityDestroyerTests: XCTestCase {

    var testDatabase: TestDatabase!

    override func setUp() {
        super.setUp()

        testDatabase = TestDatabase()
    }

    func testDeleteMediasOlderThan() {
        setupVideoMessages()
        
        let deleteTests = [
            // days diff, expected count of deleted media
            [-2, 8],
            [nil, 2],
        ]
        
        let userCalendar = Calendar.current
        
        for deleteTest in deleteTests {
            var olderThan: Date?
            if let daysAdd = deleteTest[0] {
                olderThan = userCalendar.date(byAdding: .day, value: daysAdd, to: Date())
            }
            
            let ed = testDatabase.entityManager.entityDestroyer
            let count = ed.deleteMedias(olderThan: olderThan)
            
            XCTAssertEqual(count, deleteTest[1]!, "not expected count of deleted medias")
        }
    }
    
    func testDeleteMessagesOlderThan() {
        setupVideoMessages()
        
        let deleteTests = [
            // days diff, expected count of deleted media
            [-2, 8],
            [nil, 2],
        ]
        
        let userCalendar = Calendar.current
        
        for deleteTest in deleteTests {
            var olderThan: Date?
            if let daysAdd = deleteTest[0] {
                olderThan = userCalendar.date(byAdding: .day, value: daysAdd, to: Date())
            }
            
            let ed = testDatabase.entityManager.entityDestroyer
            let count = ed.deleteMessages(olderThan: olderThan)
            
            XCTAssertEqual(count, deleteTest[1]!, "not expected count of deleted messages")
        }
    }

    func testDeleteMessageContentOfLocationMessageEntity() throws {
        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 1,
                longitude: 1,
                poiAddress: "POI address",
                poiName: "POI name",
                isOwn: true
            )
        }

        let entityManager = testDatabase.entityManager
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertEqual(message.latitude, 0)
        XCTAssertEqual(message.longitude, 0)
        XCTAssertEqual(message.accuracy, 0)
        XCTAssertNil(message.poiAddress)
        XCTAssertNil(message.poiName)
    }

    func testDeleteMessageContentOfTextMessageEntity() throws {
        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "Test",
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }

        let entityManager = testDatabase.entityManager
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertEqual(message.text, "")
    }

    func testDeleteMessageContentOfFileMessageEntity() throws {
        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            let data = dbPreparer.createFileDataEntity(data: Data([11, 22]))
            let thumbnail = dbPreparer.createImageDataEntity(data: Data([33]), height: 33, width: 33)
            let message = dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                data: data,
                thumbnail: thumbnail,
                mimeType: "PDF",
                isOwn: true,
                caption: "Test PDF"
            )
            message.fileName = "test.pdf"
            message.json = "{test: 1}"

            return message
        }

        let entityManager = testDatabase.entityManager
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.data)
        XCTAssertNil(message.thumbnail)
        XCTAssertEqual(message.mimeType, "")
        XCTAssertEqual(message.fileName, "")
        XCTAssertEqual(message.caption, "")
        XCTAssertEqual(message.json, "")
    }

    func testDeleteMessageContentOfImageMessageEntity() throws {
        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            let image = dbPreparer.createImageDataEntity(data: Data([11, 22]), height: 22, width: 22)
            let thumbnail = dbPreparer.createImageDataEntity(data: Data([33]), height: 33, width: 33)
            let message = dbPreparer.createImageMessageEntity(
                conversation: dbPreparer.createConversation(),
                image: image,
                thumbnail: thumbnail,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            return message
        }

        let entityManager = testDatabase.entityManager
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.image)
        XCTAssertNil(message.thumbnail)
    }

    func testDeleteMessageContentOfVideoMessageEntity() throws {
        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
            let video = dbPreparer.createVideoDataEntity(data: Data([11, 22]))
            let thumbnail = dbPreparer.createImageDataEntity(data: Data([33]), height: 33, width: 33)
            let message = dbPreparer.createVideoMessageEntity(
                conversation: conversation,
                video: video,
                duration: 10,
                thumbnail: thumbnail,
                date: Date(),
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            return message
        }

        let entityManager = testDatabase.entityManager
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.video)
        XCTAssertEqual(message.duration, 0)
    }

    func testDeleteBasicConversation() {
        let entityManager = testDatabase.entityManager

        let deletableContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        )
        
        entityManager.entityDestroyer.delete(conversation: deletableContactAndConversation.conversation)

        guard let fetchedContact = entityManager.entityFetcher.contactEntity(for: "ECHOECHO") else {
            XCTFail()
            return
        }
        
        guard let conversations = fetchedContact.conversations else {
            XCTFail()
            return
        }
        
        guard let groupConversations = fetchedContact.groupConversations else {
            XCTFail()
            return
        }
        
        XCTAssert(conversations.isEmpty)
        XCTAssert(groupConversations.isEmpty)
    }
    
    func testDeleteBasicConversationAndMessages() {
        let entityManager = testDatabase.entityManager

        let deletableContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        )
        
        let remainingContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECH1"
        )
        
        var ultimatelyDeletedMessageIDs = Set<Data>()
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: deletableContactAndConversation.conversation,
                    setLastUpdate: true
                )
                message.sender = deletableContactAndConversation.contact
                
                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: remainingContactAndConversation.conversation,
                    setLastUpdate: true
                )
                message.sender = remainingContactAndConversation.contact
            }
        }
        
        // End Prepare
        
        // Start Verify Test Correctly Prepared
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        XCTAssertEqual(try! testDatabase.context.main.fetch(fetchMessages).count, 200)

        fetchMessages.predicate = NSPredicate(format: "conversation = %@", deletableContactAndConversation.conversation)
        
        let prevMessages = try! testDatabase.context.main.fetch(fetchMessages)
        XCTAssertEqual(prevMessages.count, 100)
        
        guard let tContact = entityManager.entityFetcher.contactEntity(for: "ECHOECHO") else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(tContact.conversations!.count, 1)
        
        // End Verify Test Correctly Prepared
        
        // Test
        
        entityManager.entityDestroyer.delete(conversation: deletableContactAndConversation.conversation)

        verifyDatabase(
            with: entityManager,
            deletedContact: false,
            ultimatelyDeletedMessageIDs: ultimatelyDeletedMessageIDs,
            existingMessageIDs: nil,
            conversationsCount: 1,
            totalMessagesCount: 100,
            totalContactsCount: 2
        )
    }
    
    func testDeleteConversationGroupConversationAndMessages() {
        // Prepare Test
        let entityManager = testDatabase.entityManager

        let deletableContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        )
        
        var members = createThreeGroupMembers(entityManager: entityManager)
        members.append(deletableContactAndConversation.contact)
        
        var ultimatelyDeletedMessageIDs = Set<Data>()
        var existingMessageIDs = Set<Data>()
        
        entityManager.performAndWaitSave {
            for i in 0..<100 {
                _ = self.testDatabase.preparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.groupID = BytesUtility.generateRandomBytes(length: 32)!
                        conversation.groupMyIdentity = deletableContactAndConversation.contact.identity
                        conversation.groupName = "TestGroup \(i)"
                        conversation.members?.formUnion(members)
                        
                        for i in 0..<100 {
                            for member in members {
                                let message = entityManager.entityCreator.textMessageEntity(
                                    text: "Text \(i)",
                                    in: conversation,
                                    setLastUpdate: true
                                )
                                message.sender = member
                                
                                existingMessageIDs.insert(message.id)
                            }
                        }
                    }
            }
        }
        
        let conversation2 = entityManager.entityCreator.conversationEntity()
        conversation2.contact = members.first

        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: deletableContactAndConversation.conversation,
                    setLastUpdate: true
                )
                message.sender = deletableContactAndConversation.contact
                
                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: conversation2,
                    setLastUpdate: true
                )
                message.sender = members.first!
                
                existingMessageIDs.insert(message.id)
            }
        }
        
        // End Prepare
        
        // Start Verify Test Correctly Prepared
        
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchMessages.predicate = NSPredicate(format: "conversation = %@", deletableContactAndConversation.conversation)
        
        let prevMessages = try! testDatabase.context.main.fetch(fetchMessages)

        XCTAssert(prevMessages.count == 100)
        
        // End Verify Test Correctly Prepared
        
        // Test
        
        entityManager.entityDestroyer.delete(conversation: deletableContactAndConversation.conversation)

        verifyDatabase(
            with: entityManager,
            deletedContact: false,
            ultimatelyDeletedMessageIDs: ultimatelyDeletedMessageIDs,
            existingMessageIDs: existingMessageIDs,
            conversationsCount: 101,
            totalMessagesCount: 40100,
            totalContactsCount: 4
        )
    }
    
    func testDeleteContactGroupConversationAndMessages() throws {
        let entityManager = testDatabase.entityManager

        let deletableContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        )

        var members = createThreeGroupMembers(entityManager: entityManager)
        members.append(deletableContactAndConversation.contact)

        var ultimatelyDeletedMessageIDs = Set<Data>()
        var existingMessageIDs = Set<Data>()

        entityManager.performAndWaitSave {
            for i in 0..<10 {
                _ = self.testDatabase.preparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.groupID = BytesUtility.generateRandomBytes(length: 32)!
                        conversation.groupMyIdentity = deletableContactAndConversation.contact.identity
                        conversation.groupName = "TestGroup \(i)"
                        conversation.members?.formUnion(members)

                        for i in 0..<10 {
                            for member in members {
                                let message = entityManager.entityCreator.textMessageEntity(
                                    text: "Text \(i)",
                                    in: conversation,
                                    setLastUpdate: true
                                )
                                message.sender = member

                                if member == deletableContactAndConversation.contact {
                                    ultimatelyDeletedMessageIDs.insert(message.id)
                                }
                                else {
                                    existingMessageIDs.insert(message.id)
                                }
                            }
                        }
                    }
            }
        }

        let conversation2 = entityManager.entityCreator.conversationEntity()
        conversation2.contact = members.first

        for i in 0..<10 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: deletableContactAndConversation.conversation,
                    setLastUpdate: true
                )
                message.sender = deletableContactAndConversation.contact

                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }

        for i in 0..<10 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessageEntity(
                    text: "Text \(i)",
                    in: conversation2,
                    setLastUpdate: true
                )
                message.sender = members.first!

                existingMessageIDs.insert(message.id)
            }
        }

        // End Prepare

        // Start Verify Test Correctly Prepared
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")

        let prevMessages = try! testDatabase.context.main.fetch(fetchMessages)

        XCTAssert(prevMessages.count == 420)

        // End Verify Test Correctly Prepared

        // Test

        entityManager.entityDestroyer.delete(contactEntity: deletableContactAndConversation.contact)

        verifyDatabase(
            with: entityManager,
            deletedContact: true,
            ultimatelyDeletedMessageIDs: ultimatelyDeletedMessageIDs,
            existingMessageIDs: existingMessageIDs,
            conversationsCount: 11,
            totalMessagesCount: 310,
            totalContactsCount: 3
        )
    }

    func testDeleteMessagesAndNullifyLastMessage() throws {
        var conversation: ConversationEntity?
        var lastMessage: BaseMessageEntity?

        let dp = testDatabase.preparer
        dp.save {
            conversation = dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )

            dp.createTextMessage(
                conversation: conversation!,
                text: "1",
                date: Date(),
                delivered: true,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: true,
                sent: true,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
            lastMessage = dp.createTextMessage(
                conversation: conversation!,
                text: "1",
                date: Date(),
                delivered: true,
                id: BytesUtility
                    .generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: true,
                sent: true,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )

            conversation?.lastMessage = lastMessage
        }

        let deleteMessage = try XCTUnwrap(lastMessage)

        let entityManager = testDatabase.entityManager
        entityManager.entityDestroyer.delete(baseMessage: deleteMessage)

        XCTAssertNotNil(conversation)
        XCTAssertNil(conversation?.lastMessage)
    }
}

// MARK: - Helper Functions

extension EntityDestroyerTests {
    private func verifyDatabase(
        with entityManager: EntityManager,
        deletedContact: Bool,
        ultimatelyDeletedMessageIDs: Set<Data>,
        existingMessageIDs: Set<Data>?,
        conversationsCount: Int,
        totalMessagesCount: Int,
        totalContactsCount: Int
    ) {
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let varExistingMessageIDs = existingMessageIDs
        
        if deletedContact {
            XCTAssertNil(entityManager.entityFetcher.contactEntity(for: "ECHOECHO"))
        }
        
        let fetchConversations = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        let refetchedConversations = try! testDatabase.context.main.fetch(fetchConversations)

        XCTAssertEqual(refetchedConversations.count, conversationsCount)
        
        let fetchContacts = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let refetchedContacts = try! testDatabase.context.main.fetch(fetchContacts)

        XCTAssertEqual(refetchedContacts.count, totalContactsCount)
        
        let allMessages = try! testDatabase.context.main.fetch(fetchMessages) as! [BaseMessageEntity]

        XCTAssertEqual(allMessages.count, totalMessagesCount)
        
        for message in allMessages {
            XCTAssert(!ultimatelyDeletedMessageIDs.contains(message.id))
        }
        
        if var varExistingMessageIDs {
            for message in allMessages {
                XCTAssertNotNil(varExistingMessageIDs.remove(message.id))
            }
            XCTAssert(varExistingMessageIDs.isEmpty)
        }
    }
    
    private func createThreeGroupMembers(entityManager: EntityManager) -> [ContactEntity] {
        var notDeletedContact: ContactEntity!
        var notDeletedContact2: ContactEntity!
        var notDeletedContact3: ContactEntity!
        
        entityManager.performAndWaitSave {
            notDeletedContact = entityManager.entityCreator.contactEntity(
                identity: "ECHOECH1",
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                sortOrderFirstName: true
            )
            notDeletedContact.contactVerificationLevel = .unverified
            notDeletedContact.publicNickname = "ECHOECH1"
            notDeletedContact.isHidden = false
            notDeletedContact.workContact = 0
        }
        
        entityManager.performAndWaitSave {
            notDeletedContact2 = entityManager.entityCreator.contactEntity(
                identity: "ECHOECH2",
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                sortOrderFirstName: true
            )
            notDeletedContact2.contactVerificationLevel = .unverified
            notDeletedContact2.publicNickname = "ECHOECH2"
            notDeletedContact2.isHidden = false
            notDeletedContact2.workContact = 0
        }
        
        entityManager.performAndWaitSave {
            notDeletedContact3 = entityManager.entityCreator.contactEntity(
                identity: "ECHOECH3",
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                sortOrderFirstName: true
            )
            notDeletedContact3.contactVerificationLevel = .unverified
            notDeletedContact3.publicNickname = "ECHOECH3"
            notDeletedContact3.isHidden = false
            notDeletedContact3.workContact = 0
        }
        
        return [notDeletedContact, notDeletedContact2, notDeletedContact3]
    }
    
    private func createContactAndConversation(entityManager: EntityManager, identity: String)
        -> (contact: ContactEntity, conversation: ConversationEntity) {
        var contact: ContactEntity!
        
        entityManager.performAndWaitSave {
            contact = entityManager.entityCreator.contactEntity(
                identity: identity,
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                sortOrderFirstName: true
            )
            contact.contactVerificationLevel = .unverified
            contact.publicNickname = identity
            contact.isHidden = false
            contact.workContact = 0
        }
        
        let conversation = entityManager.entityCreator.conversationEntity()
        conversation.contact = entityManager.entityFetcher.contactEntity(for: identity)

        assert(contact.identity == identity)
        
        return (contact, conversation)
    }
    
    private func setupVideoMessages() {
        // Setup DB for testing, insert 10 video messages
        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let thumbnail = dbPreparer.createImageDataEntity(data: Data([22]), height: 22, width: 22)
            
            let userCalendar = Calendar.current
            let toDate = Date()
            
            for index in 1...10 {
                var addDate = DateComponents()
                addDate.day = index * -1
                addDate.hour = 1

                let date = userCalendar.date(byAdding: addDate, to: toDate)

                dbPreparer.createVideoMessageEntity(
                    conversation: dbPreparer.createConversation(),
                    video: dbPreparer.createVideoDataEntity(data: Data([1])),
                    duration: 10,
                    thumbnail: thumbnail,
                    date: date!,
                    isOwn: true,
                    sender: nil,
                    remoteSentDate: Date()
                )
            }
        }
    }
}
