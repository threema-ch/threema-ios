//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@testable import Threema

class DBLoadTests: XCTestCase {

    override func setUp() {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    /// Print out shell commands to copy database and external data form simulator. To prepare database before, run methods in this file like 'testDbLoad'.
    func testCopyOldVersionOfDatabase() {
        
        let databasePath = FileUtility.appDataDirectory?.path
        
        if databasePath != nil {
            print("\nCopy 'old' version of database for testing DB migration:")
            print("""
                \n
                cd \(databasePath!)
                tar cf ThreemaDataOldVersion.tar.gz .ThreemaData_SUPPORT ThreemaData.sqlite
                mv ThreemaDataOldVersion.tar.gz ~/Documents/
                cd ~/Documents
                mkdir ThreemaDataOldVersion
                tar xf ThreemaDataOldVersion.tar.gz -C ./ThreemaDataOldVersion
                \n
                """)
            print(
                "As last step copy the directory 'ThreemaDataOldVersion' via iTunes into 'applicationDocuments' of Threema.\n"
            )
        }

        XCTAssertNotNil(databasePath)
    }
    
    /// Add 10000 messages (./Resources/test_texts.json) to ECHOECHO for testing.
    func testLoadTextMessages() throws {
        let testBundle = Bundle(for: DBLoadTests.self)

        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }
        
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))
        
        var conversation: Conversation?
        
        createContacts(for: ["ECHOECHO"])
        
        let entityManager = EntityManager()
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
            }
        }
        
        entityManager.performSyncBlockAndSafe {
            for index in 0..<100_000 {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .hour, value: index, to: Date(timeIntervalSince1970: 0))
                let message = entityManager.entityCreator.textMessage(for: conversation)!
                message.text = "\(index) - \(texts[index % texts.count])"
                message.date = date
                message.sender = conversation?.contact
                message.sent = true
                message.delivered = true
                message.read = true
                message.remoteSentDate = Date()
                print("\(index)/100'000")
            }
        }
    }
    
    func testUnreadMessagesCount() throws {
        let testBundle = Bundle(for: DBLoadTests.self)

        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }

        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))

        var conversation: Conversation?

        let entityManager = EntityManager()

        let senders = ["ECHOECHO"]
        createContacts(for: senders)
        for sender in senders {
            entityManager.performSyncBlockAndSafe {
                if let contact = entityManager.entityFetcher.contact(for: sender) {
                    conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
                }
            }

            for index in 0..<5000 {
                entityManager.performSyncBlockAndSafe {
                    let calendar = Calendar.current
                    let date = calendar.date(byAdding: .second, value: +index, to: Date())
                    let message = entityManager.entityCreator.textMessage(for: conversation)!
                    let isOwn = index % 3 == 0 ? false : true
                    message.isOwn = NSNumber(booleanLiteral: isOwn)
                    message.text = texts[index % texts.count]
                    message.date = date
                    message.sent = true
                    message.delivered = true
                    if !isOwn {
                        message.sender = conversation?.contact
                        message.read = index % 5 == 0 ? true : false
                        message.readDate = index % 5 == 0 ? date : nil
                    }
                    message.remoteSentDate = date
                }
            }
        }
    }

    func testFillGroupsWithText() throws {
        let testBundle = Bundle(for: DBLoadTests.self)

        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }
        
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))
        
        let entityManager = EntityManager()

        for num in 0..<1000 {
            for groupConversation in entityManager.entityFetcher.allGroupConversations() as! [Conversation] {
                entityManager.performSyncBlockAndSafe {
                    for contact in entityManager.entityFetcher.allContacts() as! [Contact] {
                        let calendar = Calendar.current
                        let date = calendar.date(byAdding: .hour, value: 1, to: Date(timeIntervalSince1970: 0))
                        let message = entityManager.entityCreator.textMessage(for: groupConversation)!
                        message.text = "Message \(num) from \(contact.identity) \(texts[num % texts.count])"
                        message.date = date
                        message.sender = contact
                        message.isOwn = NSNumber(booleanLiteral: false)
                        message.remoteSentDate = date
                    }
                }
            }
        }

        if let groupConversations = entityManager.entityFetcher.allGroupConversations() as? [Conversation] {
            let unreadMessages = UnreadMessages(entityManager: entityManager)
            unreadMessages.totalCount(doCalcUnreadMessagesCountOf: Set(groupConversations))
        }
    }
    
    /// Adding 160 contacts with Threema ID's (./Resources/test_ids.txt) for testing.
    func testLoadContacts() throws {
        let testBundle = Bundle(for: DBLoadTests.self)
        let filePath = try XCTUnwrap(testBundle.path(forResource: "test_ids", ofType: "txt"))
        
        do {
            var fetchIdentities = [String]()
            
            let ids = try String(contentsOfFile: filePath, encoding: .utf8)
            for id in ids.components(separatedBy: .newlines) {
                if !id.isEmpty {
                    fetchIdentities.append(id)
                }
            }
            
            try addContacts(for: fetchIdentities, entityManager: EntityManager())
        }
        catch {
            print(error)
        }
    }
    
    // This doesn't seem to work right now as the network calls seem to block infinitely
    // This is probably due to the fact of `semaphore.wait()` blocking the main thread and `fetchBulkIdentityInfo`
    // running on the main thread as well.
    private func addContacts(for ids: [String], entityManager: EntityManager) throws {
        let queue = DispatchQueue.global()
        let semaphore = DispatchSemaphore(value: 0)
        
        var pks = [String: Data]()

        queue.async {
            let api = ServerAPIConnector()
            api.fetchBulkIdentityInfo(ids, onCompletion: { identities, publicKeys, _, _, _ in
                
                for index in 0..<(identities!.count - 1) {
                    pks[identities![index] as! String] = Data(base64Encoded: publicKeys![index] as! String)
                }
                
                semaphore.signal()
            }) { error in
                print(error?.localizedDescription ?? "")
                
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        for pk in pks {
            print("add id: \(pk.key)")
            
            entityManager.performSyncBlockAndSafe {
                if let contact = entityManager.entityCreator.contact() {
                    contact.identity = pk.key
                    contact.verificationLevel = 0
                    contact.publicNickname = pk.key
                    contact.isContactHidden = false
                    contact.workContact = 0
                    contact.publicKey = pk.value
                }
            }
        }
    }
    
    func testAssignImagesToAllContacts() {
        let entityManager = EntityManager()
        
        for contact in entityManager.entityFetcher.allContacts() as! [Contact] {
            
            let testBundle = Bundle(for: DBLoadTests.self)
            let testImageURL = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
            let testImageData = try? Data(contentsOf: testImageURL!)
            let resizedTestImage = MediaConverter.scaleImageData(testImageData!, toMaxSize: 512)?
                .jpegData(compressionQuality: 0.99)!
            
            entityManager.performSyncBlockAndSafe {
                let imageData = entityManager.entityCreator.imageData()!
                imageData.data = resizedTestImage
                imageData.width = 512
                imageData.height = 512
                
                contact.contactImage = imageData
            }
        }
    }
    
    func testLoadImageFileMessages() {
        var conversation: Conversation?
        
        createContacts(for: ["ECHOECHO"])
        let entityManager = EntityManager(withChildContextForBackgroundProcess: false)
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = (entityManager.conversation(forContact: contact, createIfNotExisting: true))!
            }
        }
        
        for i in 0..<1000 {
            print("\(i)/1000")
            let testBundle = Bundle(for: DBLoadTests.self)
            let testImageURL = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
            let testImageData = try? Data(contentsOf: testImageURL!)
            
            loadImage(with: testImageData!, conversation!, entityManager)
        }
    }
    
    func loadImage(with imageData: Data, _ conversation: Conversation, _ entityManager: EntityManager) {
        
        entityManager.performSyncBlockAndSafe {
            let dbFile: FileData = (entityManager.entityCreator.fileData())!
            dbFile.data = imageData
            
            let thumbnailFile: ImageData = entityManager.entityCreator.imageData()!
            thumbnailFile.data = MediaConverter.getThumbnailFor(UIImage(data: imageData)!)?
                .jpegData(compressionQuality: 1.0)
            
            let message: FileMessageEntity = (entityManager.entityCreator.fileMessageEntity(for: conversation))!
            message.data = dbFile
            message.thumbnail = thumbnailFile
            message.fileName = "Bild.jpeg"
            message.fileSize = NSNumber(integerLiteral: dbFile.data!.count)
            message.mimeType = "image/jpeg"
            message.type = NSNumber(integerLiteral: 1)
            message.date = Date(timeIntervalSinceReferenceDate: TimeInterval(-1 * Int.random(in: 0...223_456_789)))
            message.sender = conversation.contact
            message.sent = true
            message.delivered = true
            message.read = true
            message.remoteSentDate = Date()
        }
    }
    
    // TODO: Call messages (IOS-3033)
    
    // MARK: - Groups with single set of messages
    
    // MARK: Text messages with quotes

    func testGroupWithQuoteMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let testBundle = Bundle(for: DBLoadTests.self)
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Quote Messages", with: [], entityManager: entityManager)
        
        // Sender
        createContacts(for: ["ECHOECHO"])
        let senderContact = try XCTUnwrap(entityManager.entityFetcher.contact(for: "ECHOECHO"))
        
        // Load texts
        let testTextsURL = try XCTUnwrap(testBundle.url(forResource: "test_texts", withExtension: "json"))
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: testTextsURL))
        
        // Create set of messages to quote
        
        var quotableMessages = [BaseMessage]()
        
        // Text messages
        entityManager.performSyncBlockAndSafe {
            let outgoingMessage = entityManager.entityCreator.textMessage(for: group.conversation)!
            outgoingMessage.text = texts[0]
            outgoingMessage.date = Date()
            outgoingMessage.sent = true
            outgoingMessage.delivered = true
            outgoingMessage.remoteSentDate = Date()
            outgoingMessage.deliveryDate = Date()
            outgoingMessage.isOwn = true
            quotableMessages.append(outgoingMessage)
            
            let incomingMessage = entityManager.entityCreator.textMessage(for: group.conversation)!
            incomingMessage.text = texts[1]
            incomingMessage.date = Date()
            incomingMessage.sent = true
            incomingMessage.delivered = true
            incomingMessage.remoteSentDate = Date()
            incomingMessage.deliveryDate = Date()
            incomingMessage.isOwn = false
            incomingMessage.sender = senderContact
            quotableMessages.append(incomingMessage)
        }
        
        // File messages
        
        var senderItems = [URLSenderItem]()
        
        // Load image
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageSenderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: testImageURL))
        senderItems.append(imageSenderItem)
        
        // Load sticker
        let testStickerURL = try XCTUnwrap(testBundle.url(forResource: "Sticker-sine_wave", withExtension: "png"))
        let stickerSenderItem = try XCTUnwrap(URLSenderItem(
            url: testStickerURL,
            type: UTType.png.identifier,
            renderType: 2,
            sendAsFile: false
        ))
        senderItems.append(stickerSenderItem)
        
        // Load animated image
        let testAnimatedImageURL = try XCTUnwrap(testBundle.url(
            forResource: "Animated_two_spur_gears_1_2",
            withExtension: "gif"
        ))
        let animatedImageSenderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: testAnimatedImageURL))
        senderItems.append(animatedImageSenderItem)
        
        // Load animated sticker
        let testAnimatedStickerURL = try XCTUnwrap(testBundle.url(
            forResource: "Animated_sticker-sine_wave",
            withExtension: "gif"
        ))
        let animatedStickerSenderItem = try XCTUnwrap(URLSenderItem(
            url: testAnimatedStickerURL,
            type: UTType.gif.identifier,
            renderType: 2,
            sendAsFile: false
        ))
        senderItems.append(animatedStickerSenderItem)
        
        // Load video
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let videoSenderItem = try XCTUnwrap(VideoURLSenderItemCreator().senderItem(from: testVideoURL))
        senderItems.append(videoSenderItem)
        
        // Load voice message
        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "audioAnalyzerTest", withExtension: "m4a"))
        let voiceSenderItem = try XCTUnwrap(URLSenderItem(
            url: testVoiceURL,
            type: UTType.mpeg4Audio.identifier,
            renderType: 1,
            sendAsFile: false
        ))
        senderItems.append(voiceSenderItem)
        
        // Load document
        let testFileURL = try XCTUnwrap(testBundle.url(forResource: "Test", withExtension: "pdf"))
        let fileSenderItem = try XCTUnwrap(URLSenderItem(
            url: testFileURL,
            type: UTType.pdf.identifier,
            renderType: 0,
            sendAsFile: false
        ))
        senderItems.append(fileSenderItem)
        
        // Add quotable file messages
        
        var fileMessageCreationError: Error?
        
        entityManager.performSyncBlockAndSafe {
            do {
                for senderItem in senderItems {
                    let ownFileMessageEntity = try entityManager.entityCreator.createFileMessageEntity(
                        for: senderItem,
                        in: group.conversation
                    )
                    ownFileMessageEntity.isOwn = true
                    quotableMessages.append(ownFileMessageEntity)
                    
                    let otherFileMessageEntity = try entityManager.entityCreator.createFileMessageEntity(
                        for: senderItem,
                        in: group.conversation
                    )
                    otherFileMessageEntity.isOwn = false
                    otherFileMessageEntity.sender = senderContact
                    quotableMessages.append(otherFileMessageEntity)
                    
                    // This needs to be last otherwise the `renderType` of stickers will be 1 instead of 2
                    senderItem.caption = texts.randomElement() ?? "Caption"
                    let captionFileMessageEntity = try entityManager.entityCreator.createFileMessageEntity(
                        for: senderItem,
                        in: group.conversation
                    )
                    captionFileMessageEntity.isOwn = false
                    captionFileMessageEntity.sender = senderContact
                    quotableMessages.append(captionFileMessageEntity)
                }
            }
            catch {
                fileMessageCreationError = error
            }
        }
        
        if let fileMessageCreationError = fileMessageCreationError {
            XCTFail(fileMessageCreationError.localizedDescription)
        }
        
        // Location messages
        
        let testLocationsURL = try XCTUnwrap(testBundle.url(forResource: "test_locations", withExtension: "json"))
        let locations = try JSONDecoder().decode([Location].self, from: Data(contentsOf: testLocationsURL))
        
        entityManager.performSyncBlockAndSafe {
            let ownLocationMessage = entityManager.entityCreator.locationMessage(for: group.conversation)!
            ownLocationMessage.latitude = locations[0].latitude as NSNumber
            ownLocationMessage.longitude = locations[0].longitude as NSNumber
            ownLocationMessage.accuracy = locations[0].accuracy as NSNumber
            ownLocationMessage.poiName = locations[0].name
            ownLocationMessage.poiAddress = locations[0].address
            ownLocationMessage.isOwn = true
            quotableMessages.append(ownLocationMessage)
            
            let otherLocationMessage = entityManager.entityCreator.locationMessage(for: group.conversation)!
            otherLocationMessage.latitude = locations[2].latitude as NSNumber
            otherLocationMessage.longitude = locations[2].longitude as NSNumber
            otherLocationMessage.accuracy = locations[2].accuracy as NSNumber
            otherLocationMessage.poiName = locations[2].name
            otherLocationMessage.poiAddress = locations[2].address
            otherLocationMessage.isOwn = false
            otherLocationMessage.sender = senderContact
            quotableMessages.append(otherLocationMessage)

            let anotherLocationMessage = entityManager.entityCreator.locationMessage(for: group.conversation)!
            anotherLocationMessage.latitude = locations[3].latitude as NSNumber
            anotherLocationMessage.longitude = locations[3].longitude as NSNumber
            anotherLocationMessage.accuracy = locations[3].accuracy as NSNumber
            anotherLocationMessage.poiName = locations[3].name
            anotherLocationMessage.poiAddress = locations[3].address
            anotherLocationMessage.isOwn = false
            anotherLocationMessage.sender = senderContact
            quotableMessages.append(anotherLocationMessage)
        }
        
        // TODO: Add quotable ballots to `quotableMessages` (IOS-3033)
        
        // Create quote messages
        
        entityManager.performSyncBlockAndSafe {
            for index in 0..<numberOfMessagesToAdd {
                let message = entityManager.entityCreator.textMessage(for: group.conversation)!
                message.text = "\(index) - \(texts[index % texts.count])"
                message.date = Date()
                message.sent = true
                message.delivered = true
                message.remoteSentDate = Date()
                message.deliveryDate = Date()
                
                // Don't add a quote to every forth message
                if index % 4 > 0 {
                    message.quotedMessageID = quotableMessages[index % quotableMessages.count].id
                }
                
                if index % (alternateEveryXMessage * 2) >= alternateEveryXMessage {
                    // incoming message
                    message.isOwn = false
                    message.sender = senderContact
                }
                else {
                    // outgoing message
                    message.isOwn = true
                }
            }
        }
    }
    
    // MARK: Image file messages

    func testGroupWithImageFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Image File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageSenderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: testImageURL))
        
        // Create messages
        try add(
            senderItem: imageSenderItem,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: Sticker file messages

    func testGroupWithStickerFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Sticker File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testStickerURL = try XCTUnwrap(testBundle.url(forResource: "Sticker-sine_wave", withExtension: "png"))
        let stickerSenderItem = try XCTUnwrap(URLSenderItem(
            url: testStickerURL,
            type: UTType.png.identifier,
            renderType: 2,
            sendAsFile: false
        ))
        
        // Create messages
        try add(
            senderItem: stickerSenderItem,
            showCaptions: false,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: Animated image file messages

    func testGroupWithAnimatedImageFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Animated Image File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testAnimatedImageURL = try XCTUnwrap(testBundle.url(
            forResource: "Animated_two_spur_gears_1_2",
            withExtension: "gif"
        ))
        let animatedImageSenderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: testAnimatedImageURL))
        
        // Create messages
        try add(
            senderItem: animatedImageSenderItem,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: Animated sticker file messages
    
    func testGroupWithAnimatedStickerFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Animated Sticker File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testAnimatedStickerURL = try XCTUnwrap(testBundle.url(
            forResource: "Animated_sticker-sine_wave",
            withExtension: "gif"
        ))
        let animatedStickerSenderItem = try XCTUnwrap(URLSenderItem(
            url: testAnimatedStickerURL,
            type: UTType.gif.identifier,
            renderType: 2,
            sendAsFile: false
        ))
        
        // Create messages
        try add(
            senderItem: animatedStickerSenderItem,
            showCaptions: false,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: Video file messages

    func testGroupWithVideoFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Video File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let videoSenderItem = try XCTUnwrap(VideoURLSenderItemCreator().senderItem(from: testVideoURL))
        
        // Create messages
        try add(
            senderItem: videoSenderItem,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: Voice file messages

    func testGroupWithVoiceFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Voice File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "audioAnalyzerTest", withExtension: "m4a"))
        let voiceSenderItem = try XCTUnwrap(URLSenderItem(
            url: testVoiceURL,
            type: UTType.mpeg4Audio.identifier,
            renderType: 1,
            sendAsFile: false
        ))
        
        // Create messages
        try add(
            senderItem: voiceSenderItem,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: File file messages

    func testGroupWithFileFileMessages() async throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "File File Messages", with: [], entityManager: entityManager)
        
        // Load image
        let testBundle = Bundle(for: DBLoadTests.self)
        let testFileURL = try XCTUnwrap(testBundle.url(forResource: "Test", withExtension: "pdf"))
        let fileSenderItem = try XCTUnwrap(URLSenderItem(
            url: testFileURL,
            type: UTType.pdf.identifier,
            renderType: 0,
            sendAsFile: false
        ))
        
        // Create messages
        try add(
            senderItem: fileSenderItem,
            to: group,
            numberOfMessagesToAdd,
            timesAndAlternateEvery: alternateEveryXMessage,
            entityManager: entityManager
        )
    }
    
    // MARK: File message helper
    
    private func add(
        senderItem: URLSenderItem,
        caption: String? = nil,
        showCaptions: Bool = true,
        to group: Group,
        _ times: Int,
        timesAndAlternateEvery alternateEveryXMessage: Int,
        entityManager: EntityManager
    ) throws {
        let testBundle = Bundle(for: DBLoadTests.self)

        let testCaptionsURL = try XCTUnwrap(testBundle.url(forResource: "test_texts", withExtension: "json"))
        let captions = try JSONDecoder().decode([String].self, from: Data(contentsOf: testCaptionsURL))
        
        createContacts(for: ["ECHOECHO"])
        let senderContact = try XCTUnwrap(entityManager.entityFetcher.contact(for: "ECHOECHO"))
        
        for index in 0..<times {
            if showCaptions {
                // Add a caption if given or to every eighth message
                if let caption = caption {
                    senderItem.caption = caption
                }
                else if index % 8 == 0 {
                    senderItem.caption = captions[(index / 8) % captions.count]
                }
                else {
                    senderItem.caption = nil
                }
            }
            
            var fileMessageCreationError: Error?
            
            entityManager.performSyncBlockAndSafe {
                do {
                    let fileMessageEntity = try entityManager.entityCreator.createFileMessageEntity(
                        for: senderItem,
                        in: group.conversation
                    )
                    
                    if index % (alternateEveryXMessage * 2) >= alternateEveryXMessage {
                        // incoming message
                        fileMessageEntity.isOwn = false
                        fileMessageEntity.sender = senderContact
                    }
                    else {
                        // outgoing message
                        fileMessageEntity.isOwn = true
                    }
                }
                catch {
                    fileMessageCreationError = error
                }
            }
            
            if let fileMessageCreationError = fileMessageCreationError {
                XCTFail(fileMessageCreationError.localizedDescription)
            }
        }
    }
    
    // MARK: Location messages

    func testGroupWithLocationMessages() throws {
        let numberOfMessagesToAdd = 100
        let alternateEveryXMessage = 5
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "Location Messages", with: [], entityManager: entityManager)
        
        // Fetch contact
        createContacts(for: ["ECHOECHO"])
        let senderContact = try XCTUnwrap(entityManager.entityFetcher.contact(for: "ECHOECHO"))
        
        // Load and add locations
        
        let testBundle = Bundle(for: DBLoadTests.self)
        let testLocationsURL = try XCTUnwrap(testBundle.url(forResource: "test_locations", withExtension: "json"))
        let locations = try JSONDecoder().decode([Location].self, from: Data(contentsOf: testLocationsURL))
    
        for index in 0..<numberOfMessagesToAdd {
            let location = locations[index % locations.count]
            
            entityManager.performSyncBlockAndSafe {
                let locationMessage = entityManager.entityCreator.locationMessage(for: group.conversation)!
                
                locationMessage.latitude = location.latitude as NSNumber
                locationMessage.longitude = location.longitude as NSNumber
                locationMessage.accuracy = location.accuracy as NSNumber
                locationMessage.poiName = location.name
                locationMessage.poiAddress = location.address
                
                if index % (alternateEveryXMessage * 2) >= alternateEveryXMessage {
                    // incoming message
                    locationMessage.isOwn = false
                    locationMessage.sender = senderContact
                }
                else {
                    // outgoing message
                    locationMessage.isOwn = true
                }
            }
        }
    }
    
    /// Used to parse  `test_locations.json`
    private struct Location: Codable {
        let name: String?
        let address: String?
        let latitude: Double
        let longitude: Double
        let accuracy: Double
    }
    
    // TODO: Ballot messages (IOS-3033)
    
    // MARK: System messages
    
    func testGroupWithSystemMessages() throws {
        let memberIDsToAddAndRemove = [
            "79PNJP93",
            "86C8TPSV",
            "89A6R535",
            "8K4PHKZ8",
            "938BYJZ2",
            "9DA769XW",
            "9UMM8RUX",
            "AMNR4PJH",
            "ANH9VK8J",
            "BR84ASE5",
            "BV9P56XX",
            "CHD7UH2B",
            "CPPDA7HM",
            "CT2AP9XA",
            "D2CJFSC2",
            "DSWMK3UZ",
            "EE365MVK",
        ]
        
        createContacts(for: memberIDsToAddAndRemove)
        
        let entityManager = EntityManager()
        
        // Create group
        let group = try createGroup(named: "System Messages", with: [], entityManager: entityManager)
        let groupManager: GroupManagerProtocol = GroupManager(entityManager: entityManager)
        
        // Add system messages by doing different group updates
        
        var expectations = [XCTestExpectation]()
        
        // Doing this with an expectation blocks the test
        groupManager.setName(group: group, name: "System Messages 1")
            .catch { error in
                XCTFail(error.localizedDescription)
            }
        
        let createOrUpdate1Expectation = expectation(description: "Create or update 1")
        groupManager.createOrUpdate(
            groupID: group.groupID,
            creator: MyIdentityStore.shared().identity,
            members: Set(memberIDsToAddAndRemove),
            systemMessageDate: Date()
        )
        .done { _ in
            createOrUpdate1Expectation.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
            createOrUpdate1Expectation.fulfill()
        }
        expectations.append(createOrUpdate1Expectation)
        
        let createOrUpdate2Expectation = expectation(description: "Create or update 2")
        groupManager.createOrUpdate(
            groupID: group.groupID,
            creator: MyIdentityStore.shared().identity,
            members: [],
            systemMessageDate: Date()
        )
        .done { _ in
            createOrUpdate2Expectation.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
            createOrUpdate2Expectation.fulfill()
        }
        expectations.append(createOrUpdate2Expectation)
        
        wait(for: expectations, timeout: 10)
    }
    
    // MARK: Example group
    
    /// An example "Hikers" group
    ///
    /// Generates a group chat with named members and a set of messages. This is useful for demos.
    func testExampleGroup() throws {
        let groupMemberIDsAndNames = [
            "4PBBKVUS": "Emily Yeung",
            "86C8TPSV": "Peter Schreiner",
            "9UMM8RUX": "Robert Diaz",
            "78HFFYMF": "Lisa Goldman",
            "4TWXB3EP": "Hanna Schmidt",
        ]

        // Ensure all contacts exist
        createContacts(for: Array(groupMemberIDsAndNames.keys))
        
        let entityManager = EntityManager()

        // Load all contacts and assign the names
        let members = try groupMemberIDsAndNames.map { id, name -> Contact in
            let contact = try XCTUnwrap(entityManager.entityFetcher.contact(for: id))
            
            let names = name.components(separatedBy: .whitespaces)
            entityManager.performSyncBlockAndSafe {
                contact.firstName = names.first
                contact.lastName = names.last
            }
            
            return contact
        }
        
        let group = try createGroup(
            named: "Hikers",
            with: Array(groupMemberIDsAndNames.keys),
            entityManager: entityManager
        )
        
        // Add messages
        
        addTextMessage("Hello", sender: members[0], in: group, entityManager: entityManager)
        addTextMessage(
            "Who's up for a hike next weekend?",
            sender: members[0],
            in: group,
            entityManager: entityManager
        )
        
        addTextMessage("I'm in!", sender: members[1], in: group, entityManager: entityManager)
        addTextMessage("Let's do it. 🥾", sender: members[2], in: group, entityManager: entityManager)
        
        let testBundle = Bundle(for: DBLoadTests.self)
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageSenderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: testImageURL))
        try add(
            senderItem: imageSenderItem,
            caption: "I can't, but last weekend was amazing.",
            to: group,
            1,
            timesAndAlternateEvery: 1,
            entityManager: entityManager
        )
        
        addTextMessage(
            "I need to check how my schedule looks like. When do you plan to go? Only one day or both days?",
            sender: members[3],
            in: group,
            entityManager: entityManager
        )
        
        let testFileURL = try XCTUnwrap(testBundle.url(forResource: "Hike Churfirsten", withExtension: "gpx"))
        let fileSenderItem = try XCTUnwrap(URLSenderItem(
            url: testFileURL,
            type: UTType.pdf.identifier,
            renderType: 0,
            sendAsFile: false
        ))
        fileSenderItem.caption = "I would suggest this one day hike. What do you think?"
        
        var fileMessageCreationError: Error?
        
        entityManager.performSyncBlockAndSafe {
            do {
                let fileMessageEntity = try entityManager.entityCreator.createFileMessageEntity(
                    for: fileSenderItem,
                    in: group.conversation
                )
                
                fileMessageEntity.isOwn = false
                fileMessageEntity.sender = members[0]
            }
            catch {
                fileMessageCreationError = error
            }
        }
        
        if let fileMessageCreationError = fileMessageCreationError {
            XCTFail(fileMessageCreationError.localizedDescription)
        }
    }
    
    // TODO: Helper
    
    private func createGroup(named: String, with members: [String], entityManager: EntityManager) throws -> Group {
        let groupManager: GroupManagerProtocol = GroupManager(entityManager: entityManager)
            
        let groupID = try XCTUnwrap(BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength))
        let groupCreator = try XCTUnwrap(MyIdentityStore.shared().identity)

        // Creation
        
        var groupPlaceholder: Group?
        let groupExpectation = expectation(description: "Create or update group")
        
        groupManager.createOrUpdate(
            groupID: groupID,
            creator: groupCreator,
            members: Set(members),
            systemMessageDate: Date()
        )
        .done { createdOrUpdatedGroup, _ in
            groupPlaceholder = createdOrUpdatedGroup
            groupExpectation.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
            groupExpectation.fulfill()
        }
        
        wait(for: [groupExpectation], timeout: 10)
        
        // Get created group
        let group = try XCTUnwrap(groupPlaceholder)
        
        // Set name
        groupManager.setName(group: group, name: named)
            .catch { error in
                XCTFail(error.localizedDescription)
            }
        
        return group
    }
    
    // Workaround to add contacts as `addContacts(for:entityManager:)` doesn't seem to work
    private func createContacts(for ids: [String]) {
        var contactStoreExpectations = [XCTestExpectation]()
        for id in ids {
            let contactStoreExpectation = expectation(description: "Add contact to contact store")
            ContactStore.shared().addContact(
                with: id,
                verificationLevel: Int32(kVerificationLevelUnverified)
            ) { _, _ in
                contactStoreExpectation.fulfill()
            } onError: { error in
                XCTFail(error.localizedDescription)
                contactStoreExpectation.fulfill()
            }
            contactStoreExpectations.append(contactStoreExpectation)
        }
        wait(for: contactStoreExpectations, timeout: 10)
    }
    
    private func addTextMessage(
        _ text: String,
        quoteID: Data? = nil,
        sender: Contact? = nil,
        in group: Group,
        entityManager: EntityManager
    ) {
        entityManager.performSyncBlockAndSafe {
            let message = entityManager.entityCreator.textMessage(for: group.conversation)!
            
            message.text = text
            
            message.date = Date()
            message.sent = true
            message.remoteSentDate = Date()
            message.delivered = true
            message.deliveryDate = Date()
            
            message.quotedMessageID = quoteID
            
            if let sender = sender {
                message.isOwn = false
                message.sender = sender
            }
            else {
                message.isOwn = true
            }
        }
    }
    
    // MARK: - Migration test
    
    func testAddTextMessagesForMigration() throws {
        let numberOfMessages = 200_000
        
        let testBundle = Bundle(for: DBLoadTests.self)
        let textsPath = try XCTUnwrap(testBundle.url(forResource: "test_texts", withExtension: "json"))
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))
        
        var conversation: Conversation?
        
        createContacts(for: ["ECHOECHO"])
        
        let entityManager = EntityManager()
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
            }
        }
        
        entityManager.performSyncBlockAndSafe {
            for index in 0..<(numberOfMessages / 2) {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .hour, value: -(index * 8), to: Date())
                let message = entityManager.entityCreator.textMessage(for: conversation)!
                message.text = "\(index) - \(texts[index % texts.count])"
                message.isOwn = false
                message.sender = conversation?.contact

                message.sent = true
                message.remoteSentDate = date
                message.date = Date()
                message.delivered = true
                message.deliveryDate = Date()
                message.read = true
                message.readDate = Date()
                
                print("Batch 1: \(index)/\(numberOfMessages / 2)")
            }
        }
        
        entityManager.performSyncBlockAndSafe {
            for index in 0..<(numberOfMessages / 2) {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .hour, value: -(index * 8), to: Date())!
                let message = entityManager.entityCreator.textMessage(for: conversation)!
                message.text = "\(index) - \(texts[index % texts.count])"
                message.isOwn = true

                message.date = date
                message.sent = true
                message.remoteSentDate = calendar.date(byAdding: .hour, value: +1, to: date)!
                message.delivered = true
                message.deliveryDate = calendar.date(byAdding: .hour, value: +2, to: date)!
                
                print("Batch 2: \(index)/\(numberOfMessages / 2)")
            }
        }
    }
}
