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

class DbLoadTests: XCTestCase {

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

    /// Adding conversation with ECHOECHO and adding 400 messages like images (./Resources/Bild-1.jpg 3.5MB), audio (./Resources/SmallVoice.mp3), videos (./Resources/Video-1.mp4), files (./Resources/Test.pdf) and texts. Resulting in
    ///
    func testDbLoad() {
        print(MyIdentityStore.shared().identity)
        
        var conversation: Conversation?
        
        let entityManager = EntityManager(withChildContextForBackgroundProcess: false)
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = (entityManager.conversation(forContact: contact, createIfNotExisting: true))!
            }
        }
        
        let testBundle = Bundle(for: DbLoadTests.self)
        let testImageURL = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
        let testImageData = try? Data(contentsOf: testImageURL!)
        
        let testAudioURL = testBundle.url(forResource: "SmallVoice", withExtension: "mp3")
        let testAudioData = try? Data(contentsOf: testAudioURL!)

        let testVideoURL = testBundle.url(forResource: "Video-1", withExtension: "mp4")
        let testVideoData = try? Data(contentsOf: testVideoURL!)

        let testVideoThumbnailURL = testBundle.url(forResource: "Video-1-Thumbnail", withExtension: "png")
        let testVideoThumbnailData = try? Data(contentsOf: testVideoThumbnailURL!)

        let testFileURL = testBundle.url(forResource: "Test", withExtension: "pdf")
        let testFileData = try? Data(contentsOf: testFileURL!)
        
        for ii in 1...20 {
            
            entityManager.performSyncBlockAndSafe {
                
                for i in 1...20 {
                    
                    let calendar = Calendar.current
                    let date = calendar.date(byAdding: .day, value: -10 * (i + ii), to: Date())
                    if i % 5 == 0 {
                        let message: TextMessage = (entityManager.entityCreator.textMessage(for: conversation))!
                        message.text = "test \(ii)-\(i)"
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else if i % 4 == 0 {
                        let dbAudio: AudioData = (entityManager.entityCreator.audioData())!
                        dbAudio.data = testAudioData
                        
                        let message: AudioMessageEntity = entityManager.entityCreator
                            .audioMessageEntity(for: conversation)!
                        message.audio = dbAudio
                        message.duration = NSNumber(integerLiteral: 2)
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else if i % 3 == 0 {
                        let dbVideo: VideoData = (entityManager.entityCreator.videoData())!
                        dbVideo.data = testVideoData
                        
                        let thumbnail = UIImage(data: testVideoThumbnailData!)!
                        let thumbnailData: Data = thumbnail.jpegData(compressionQuality: CGFloat(90.0))!
                        
                        let dbThumbnail: ImageData = (entityManager.entityCreator.imageData())!
                        dbThumbnail.data = thumbnailData
                        dbThumbnail.width = NSNumber(value: Float(thumbnail.size.width))
                        dbThumbnail.height = NSNumber(value: Float(thumbnail.size.height))
                        
                        let message: VideoMessageEntity = entityManager.entityCreator
                            .videoMessageEntity(for: conversation)!
                        message.video = dbVideo
                        message.thumbnail = dbThumbnail
                        message.duration = NSNumber(integerLiteral: 5)
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else if i % 2 == 0 {
                        let dbFile: FileData = (entityManager.entityCreator.fileData())!
                        dbFile.data = testFileData
                        
                        let message: FileMessageEntity = entityManager.entityCreator
                            .fileMessageEntity(for: conversation)!
                        message.data = dbFile
                        message.fileName = "Test.pdf"
                        message.fileSize = NSNumber(integerLiteral: dbFile.data!.count)
                        message.mimeType = "application/pdf"
                        message.type = NSNumber(integerLiteral: 0)
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else {
                        let dbImage: ImageData = (entityManager.entityCreator.imageData())!
                        dbImage.data = testImageData
                        
                        let image = UIImage(data: testImageData!)!
                        let thumbnail: UIImage = MediaConverter.getThumbnailFor(image)!
                        let thumbnailData: Data = thumbnail.jpegData(compressionQuality: CGFloat(90.0))!
                        
                        let dbThumbnail: ImageData = (entityManager.entityCreator.imageData())!
                        dbThumbnail.data = thumbnailData
                        dbThumbnail.width = NSNumber(value: Float(image.size.width))
                        dbThumbnail.height = NSNumber(value: Float(image.size.height))
                        
                        let message: ImageMessageEntity = entityManager.entityCreator
                            .imageMessageEntity(for: conversation)!
                        message.thumbnail = dbThumbnail
                        message.image = dbImage
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                }
            }
        }
    }
    
    /// Add 10000 messages (./Resources/test_texts.json) to ECHOECHO for testing.
    func testLoadTextMessages() throws {
        let testBundle = Bundle(for: DbLoadTests.self)

        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }
        
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))
        
        var conversation: Conversation?
        
        let entityManager = EntityManager()
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
            }
        }
        
        entityManager.performSyncBlockAndSafe {
            for index in 0..<10000 {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .hour, value: index, to: Date())
                let message = entityManager.entityCreator.textMessage(for: conversation)!
                message.text = texts[index % texts.count]
                message.date = date
                message.sender = conversation?.contact
                message.sent = true
                message.delivered = true
                message.read = true
                message.remoteSentDate = Date()
            }
        }
    }
    
    func testUnreadMessagesCount() throws {
        let testBundle = Bundle(for: DbLoadTests.self)

        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }

        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))

        var conversation: Conversation?

        let entityManager = EntityManager()

        let senders = ["ECHOECHO"]
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
        let testBundle = Bundle(for: DbLoadTests.self)

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
                        let date = calendar.date(byAdding: .hour, value: 1, to: Date())
                        let message = entityManager.entityCreator.textMessage(for: groupConversation)!
                        message.text = "Message \(num) from \(contact.identity) \(texts[num % texts.count])"
                        message.date = date
                        message.sender = contact
                        message.isOwn = NSNumber(booleanLiteral: false)
                        message.remoteSentDate = Date()
                    }
                }
            }
        }

        if let groupConversations = entityManager.entityFetcher.allGroupConversations() as? [Conversation] {
            let unreadMessages = UnreadMessages(entityManager: entityManager)
            unreadMessages.totalCount(doCalcUnreadMessagesCountOf: groupConversations)
        }
    }
    
    /// Adding 160 contacts with Threema ID's (./Resources/test_ids.txt) for testing.
    func testLoadContacts() {
        let testBundle = Bundle(for: DbLoadTests.self)
        if let filePath = testBundle.path(forResource: "test_ids", ofType: "txt") {
            let queue = DispatchQueue.global()
            let semaphore = DispatchSemaphore(value: 0)

            var pks = [String: Data]()

            do {
                var fetchIdentities = [String]()
                
                let ids = try String(contentsOfFile: filePath, encoding: .utf8)
                for id in ids.components(separatedBy: .newlines) {
                    if !id.isEmpty {
                        fetchIdentities.append(id)
                    }
                }
                
                queue.async {
                    let api = ServerAPIConnector()
                    api.fetchBulkIdentityInfo(fetchIdentities, onCompletion: { identities, publicKeys, _, _, _ in
                        
                        for index in 0..<(identities!.count - 1) {
                            pks[identities![index] as! String] = Data(base64Encoded: publicKeys![index] as! String)
                        }
                            
                        semaphore.signal()
                    }) { error in
                        print(error?.localizedDescription)

                        semaphore.signal()
                    }
                }
            }
            catch {
                print(error)
            }

            semaphore.wait()

            let entityManager = EntityManager()

            for pk in pks {
                print("add id: \(pk.key)")
                
                entityManager.performSyncBlockAndSafe {
                    if let contact = entityManager.entityCreator.contact() {
                        contact.identity = pk.key
                        contact.verificationLevel = 0
                        contact.publicNickname = pk.key
                        contact.hidden = 0
                        contact.workContact = 0
                        contact.publicKey = pk.value
                    }
                }
            }
        }
    }
    
    func testAssignImagesToAllContacts() {
        let entityManager = EntityManager()
        
        for contact in entityManager.entityFetcher.allContacts() as! [Contact] {
            
            let testBundle = Bundle(for: DbLoadTests.self)
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
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testLoadImageFileMessages() {
        var conversation: Conversation?
        
        let entityManager = EntityManager(withChildContextForBackgroundProcess: false)
        entityManager.performSyncBlockAndSafe {
            if let contact = entityManager.entityFetcher.contact(for: "ECHOECHO") {
                conversation = (entityManager.conversation(forContact: contact, createIfNotExisting: true))!
            }
        }
        
        for i in 0..<1000 {
            print("\(i)/1000")
            let testBundle = Bundle(for: DbLoadTests.self)
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
}
