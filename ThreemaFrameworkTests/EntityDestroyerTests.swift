//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2024 Threema GmbH
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

import CoreData
import XCTest
@testable import ThreemaFramework

class EntityDestroyerTests: XCTestCase {

    var objCnx: TMAManagedObjectContext!
    
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!
    
    override func setUp() {
        super.setUp()
        
        (_, objCnx, _) = DatabasePersistentContext.devNullContext()

        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
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
            
            let ed = EntityDestroyer(managedObjectContext: objCnx, myIdentityStore: MyIdentityStoreMock())
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
            
            let ed = EntityDestroyer(managedObjectContext: objCnx, myIdentityStore: MyIdentityStoreMock())
            let count = ed.deleteMessages(olderThan: olderThan)
            
            XCTAssertEqual(count, deleteTest[1]!, "not expected count of deleted messages")
        }
    }

    func testDeleteMessageContentOfLocationMessageEntity() throws {
        let dbPreparer = DatabasePreparer(context: objCnx)
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

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertEqual(message.latitude, 0)
        XCTAssertEqual(message.longitude, 0)
        XCTAssertEqual(message.accuracy, 0)
        XCTAssertNil(message.poiAddress)
        XCTAssertNil(message.poiName)
    }

    func testDeleteMessageContentOfTextMessageEntity() throws {
        let dbPreparer = DatabasePreparer(context: objCnx)
        let message = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "Test",
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertEqual(message.text, "")
    }

    func testDeleteMessageContentOfFileMessageEntity() throws {
        let dbPreparer = DatabasePreparer(context: objCnx)
        let message = dbPreparer.save {
            let data = dbPreparer.createFileData(data: Data([11, 22]))
            let thumbnail = dbPreparer.createImageData(data: Data([33]), height: 33, width: 33)
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

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.data)
        XCTAssertNil(message.thumbnail)
        XCTAssertEqual(message.mimeType, "")
        XCTAssertEqual(message.fileName, "")
        XCTAssertEqual(message.caption, "")
        XCTAssertEqual(message.json, "")
    }

    func testDeleteMessageContentOfImageMessageEntity() throws {
        let dbPreparer = DatabasePreparer(context: objCnx)
        let message = dbPreparer.save {
            let image = dbPreparer.createImageData(data: Data([11, 22]), height: 22, width: 22)
            let thumbnail = dbPreparer.createImageData(data: Data([33]), height: 33, width: 33)
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

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.image)
        XCTAssertNil(message.thumbnail)
    }

    func testDeleteMessageContentOfVideoMessageEntity() throws {
        let dbPreparer = DatabasePreparer(context: objCnx)
        let message = dbPreparer.save {
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
            let video = dbPreparer.createVideoData(data: Data([11, 22]))
            let thumbnail = dbPreparer.createImageData(data: Data([33]), height: 33, width: 33)
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

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
        try entityManager.entityDestroyer.deleteMessageContent(of: message)

        XCTAssertNil(message.video)
        XCTAssertEqual(message.duration, 0)
    }

    func testDeleteBasicConversation() {
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        
        let deletableContactAndConversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        )
        
        entityManager.entityDestroyer.delete(conversation: deletableContactAndConversation.conversation)

        guard let fetchedContact = entityManager.entityFetcher.contact(for: "ECHOECHO") else {
            XCTFail()
            return
        }
        
        guard let conversations = fetchedContact.conversations as? Set<Conversation> else {
            XCTFail()
            return
        }
        
        guard let groupConversations = fetchedContact.groupConversations as? Set<Conversation> else {
            XCTFail()
            return
        }
        
        XCTAssert(conversations.isEmpty)
        XCTAssert(groupConversations.isEmpty)
        XCTAssertNil(
            entityManager
                .conversation(forContact: deletableContactAndConversation.contact, createIfNotExisting: false)
        )
    }
    
    func testDeleteBasicConversationAndMessages() {
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        
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
                let message = entityManager.entityCreator
                    .textMessage(for: deletableContactAndConversation.conversation, setLastUpdate: true)!
                message.sender = deletableContactAndConversation.contact
                message.text = "Text \(i)"
                
                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator
                    .textMessage(for: remainingContactAndConversation.conversation, setLastUpdate: true)!
                message.sender = remainingContactAndConversation.contact
                message.text = "Text \(i)"
            }
        }
        
        // End Prepare
        
        // Start Verify Test Correctly Prepared
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        XCTAssertEqual(try! databaseMainCnx.main.fetch(fetchMessages).count, 200)
        
        fetchMessages.predicate = NSPredicate(format: "conversation = %@", deletableContactAndConversation.conversation)
        
        let prevMessages = try! databaseMainCnx.main.fetch(fetchMessages)
        XCTAssertEqual(prevMessages.count, 100)
        
        guard let tContact = entityManager.entityFetcher.contact(for: "ECHOECHO") else {
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
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        
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
                _ = DatabasePreparer(context: self.databaseMainCnx.main)
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.groupID = BytesUtility.generateRandomBytes(length: 32)!
                        conversation.groupMyIdentity = deletableContactAndConversation.contact.identity
                        conversation.groupName = "TestGroup \(i)"
                        conversation.addMembers(Set(members))
                        
                        for i in 0..<100 {
                            for member in members {
                                let message = entityManager.entityCreator.textMessage(
                                    for: conversation, setLastUpdate: true
                                )!
                                message.sender = member
                                message.text = "Text \(i)"
                                
                                existingMessageIDs.insert(message.id)
                            }
                        }
                    }
            }
        }
        
        let conversation2 = entityManager.conversation(forContact: members.first!, createIfNotExisting: true)
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator
                    .textMessage(for: deletableContactAndConversation.conversation, setLastUpdate: true)!
                message.sender = deletableContactAndConversation.contact
                message.text = "Text \(i)"
                
                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }
        
        for i in 0..<100 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessage(for: conversation2, setLastUpdate: true)!
                message.sender = members.first!
                message.text = "Text \(i)"
                
                existingMessageIDs.insert(message.id)
            }
        }
        
        // End Prepare
        
        // Start Verify Test Correctly Prepared
        
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchMessages.predicate = NSPredicate(format: "conversation = %@", deletableContactAndConversation.conversation)
        
        let prevMessages = try! databaseMainCnx.main.fetch(fetchMessages)
        
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
    
    func testDeleteContactGroupConversationAndMessages() {
        let entityManager = EntityManager(databaseContext: databaseMainCnx)

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
                _ = DatabasePreparer(context: self.databaseMainCnx.main)
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.groupID = BytesUtility.generateRandomBytes(length: 32)!
                        conversation.groupMyIdentity = deletableContactAndConversation.contact.identity
                        conversation.groupName = "TestGroup \(i)"
                        conversation.addMembers(Set(members))

                        for i in 0..<10 {
                            for member in members {
                                let message = entityManager.entityCreator.textMessage(
                                    for: conversation,
                                    setLastUpdate: true
                                )!
                                message.sender = member
                                message.text = "Text \(i)"

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

        let conversation2 = entityManager.conversation(forContact: members.first!, createIfNotExisting: true)

        for i in 0..<10 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator
                    .textMessage(for: deletableContactAndConversation.conversation, setLastUpdate: true)!
                message.sender = deletableContactAndConversation.contact
                message.text = "Text \(i)"

                ultimatelyDeletedMessageIDs.insert(message.id)
            }
        }

        for i in 0..<10 {
            entityManager.performAndWaitSave {
                let message = entityManager.entityCreator.textMessage(for: conversation2, setLastUpdate: true)!
                message.sender = members.first!
                message.text = "Text \(i)"

                existingMessageIDs.insert(message.id)
            }
        }

        // End Prepare

        // Start Verify Test Correctly Prepared
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")

        let prevMessages = try! databaseMainCnx.main.fetch(fetchMessages)

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
        var conversation: Conversation?
        var lastMessage: BaseMessage?

        let dp = DatabasePreparer(context: objCnx)
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

        let entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: objCnx, backgroundContext: nil))
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
            XCTAssertNil(entityManager.entityFetcher.contact(for: "ECHOECHO"))
        }
        
        let fetchConversations = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        let refetchedConversations = try! databaseMainCnx.main.fetch(fetchConversations)
        
        XCTAssertEqual(refetchedConversations.count, conversationsCount)
        
        let fetchContacts = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let refetchedContacts = try! databaseMainCnx.main.fetch(fetchContacts)
        
        XCTAssertEqual(refetchedContacts.count, totalContactsCount)
        
        let allMessages = try! databaseMainCnx.main.fetch(fetchMessages) as! [BaseMessage]
        
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
            notDeletedContact = entityManager.entityCreator.contact()!
            notDeletedContact.identity = "ECHOECH1"
            notDeletedContact.verificationLevel = 0
            notDeletedContact.publicNickname = "ECHOECH1"
            notDeletedContact.isContactHidden = false
            notDeletedContact.workContact = 0
            notDeletedContact.publicKey = BytesUtility.generateRandomBytes(length: Int(32))!
        }
        
        entityManager.performAndWaitSave {
            notDeletedContact2 = entityManager.entityCreator.contact()!
            notDeletedContact2.identity = "ECHOECH2"
            notDeletedContact2.verificationLevel = 0
            notDeletedContact2.publicNickname = "ECHOECH2"
            notDeletedContact2.isContactHidden = false
            notDeletedContact2.workContact = 0
            notDeletedContact2.publicKey = BytesUtility.generateRandomBytes(length: Int(32))!
        }
        
        entityManager.performAndWaitSave {
            notDeletedContact3 = entityManager.entityCreator.contact()!
            notDeletedContact3.identity = "ECHOECH3"
            notDeletedContact3.verificationLevel = 0
            notDeletedContact3.publicNickname = "ECHOECH3"
            notDeletedContact3.isContactHidden = false
            notDeletedContact3.workContact = 0
            notDeletedContact3.publicKey = BytesUtility.generateRandomBytes(length: Int(32))!
        }
        
        return [notDeletedContact, notDeletedContact2, notDeletedContact3]
    }
    
    private func createContactAndConversation(entityManager: EntityManager, identity: String)
        -> (contact: ContactEntity, conversation: Conversation) {
        var contact: ContactEntity!
        
        entityManager.performAndWaitSave {
            contact = entityManager.entityCreator.contact()!
            contact.identity = identity
            contact.verificationLevel = 0
            contact.publicNickname = identity
            contact.isContactHidden = false
            contact.workContact = 0
            contact.publicKey = BytesUtility.generateRandomBytes(length: Int(32))!
        }
        
        let conversation = entityManager.conversation(
            forContact: contact,
            createIfNotExisting: true
        )!
            
        assert(contact.identity == identity)
        
        return (contact, conversation)
    }
    
    private func setupVideoMessages() {
        // Setup DB for testing, insert 10 video messages
        let dbPreparer = DatabasePreparer(context: objCnx)
        dbPreparer.save {
            let thumbnail = dbPreparer.createImageData(data: Data([22]), height: 22, width: 22)
            
            let userCalendar = Calendar.current
            let toDate = Date()
            
            for index in 1...10 {
                var addDate = DateComponents()
                addDate.day = index * -1
                addDate.hour = 1

                let date = userCalendar.date(byAdding: addDate, to: toDate)

                dbPreparer.createVideoMessageEntity(
                    conversation: dbPreparer.createConversation(),
                    video: dbPreparer.createVideoData(data: Data([1])),
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
