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
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    /**
     Print out shell commands to copy database and external data form simulator. To prepare database before, run methods in this file like 'testDbLoad'.
    */
    func testCopyOldVersionOfDatabase() {
        
        let databasePath = DocumentManager.databaseDirectory()?.path
        
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
            print("As last step copy the directory 'ThreemaDataOldVersion' via iTunes into 'applicationDocuments' of Threema.\n")
        }

        XCTAssertNotNil(databasePath)
    }

    /**
     Adding conversation with ECHOECHO and adding 400 messages like images (./Resources/Bild-1.jpg 3.5MB), audio (./Resources/SmallVoice.mp3), videos (./Resources/Video-1.mp4), files (./Resources/Test.pdf) and texts. Resulting in
     
    */
    func testDbLoad() {
        print(MyIdentityStore.shared().identity)
        
        var conversation: Conversation? = nil
        
        let entityManager = EntityManager(forBackgroundProcess: false)
        entityManager?.performSyncBlockAndSafe({
            if let contact = entityManager?.entityFetcher?.contact(forId: "ECHOECHO") {
                conversation = (entityManager?.conversation(for: contact, createIfNotExisting: true))!
            }
        })
        
        let testBundle: Bundle = Bundle(for: DbLoadTests.self)
        let testImageUrl = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
        let testImageData = try? Data(contentsOf: testImageUrl!)
        
        let testAudioUrl = testBundle.url(forResource: "SmallVoice", withExtension: "mp3")
        let testAudioData = try? Data(contentsOf: testAudioUrl!)

        let testVideoUrl = testBundle.url(forResource: "Video-1", withExtension: "mp4")
        let testVideoData = try? Data(contentsOf: testVideoUrl!)

        let testVideoThumbnailUrl = testBundle.url(forResource: "Video-1-Thumbnail", withExtension: "png")
        let testVideoThumbnailData = try? Data(contentsOf: testVideoThumbnailUrl!)

        let testFileUrl = testBundle.url(forResource: "Test", withExtension: "pdf")
        let testFileData = try? Data(contentsOf: testFileUrl!)
        
        for ii in 1...20 {
            
            entityManager?.performSyncBlockAndSafe({
                
                for i in 1...20 {
                    
                    let calendar = Calendar.current
                    let date = calendar.date(byAdding: .day, value: -10 * (i + ii), to: Date())
                    if i % 5 == 0 {
                        let message: TextMessage = (entityManager?.entityCreator.textMessage(for: conversation))!
                        message.text = "test \(ii)-\(i)"
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else if i % 4 == 0 {
                        let dbAudio: AudioData = (entityManager?.entityCreator.audioData())!
                        dbAudio.data = testAudioData
                        
                        let message: AudioMessage = (entityManager?.entityCreator.audioMessage(for: conversation))!
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
                        let dbVideo: VideoData = (entityManager?.entityCreator.videoData())!
                        dbVideo.data = testVideoData
                        
                        let thumbnail: UIImage = UIImage(data: testVideoThumbnailData!)!
                        let thumbnailData: Data = thumbnail.jpegData(compressionQuality: CGFloat.init(90.0))!
                        
                        let dbThumbnail: ImageData = (entityManager?.entityCreator.imageData())!
                        dbThumbnail.data = thumbnailData;
                        dbThumbnail.width = NSNumber(value: Float(thumbnail.size.width))
                        dbThumbnail.height = NSNumber(value: Float(thumbnail.size.height))
                        
                        let message: VideoMessage = (entityManager?.entityCreator.videoMessage(for: conversation))!
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
                        let dbFile: FileData = (entityManager?.entityCreator.fileData())!
                        dbFile.data = testFileData
                        
                        let message: FileMessage = (entityManager?.entityCreator.fileMessage(for: conversation))!
                        message.data = dbFile
                        message.fileName = "Test.pdf"
                        message.fileSize = NSNumber(integerLiteral: dbFile.data!.count)
                        message.mimeType = "application/pdf"
                        message.type = NSNumber(integerLiteral: 0);
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                    else {
                        let dbImage: ImageData = (entityManager?.entityCreator.imageData())!
                        dbImage.data = testImageData
                        
                        let image: UIImage = UIImage(data: testImageData!)!
                        let thumbnail: UIImage = MediaConverter.getThumbnailFor(image)
                        let thumbnailData: Data = thumbnail.jpegData(compressionQuality: CGFloat.init(90.0))!
                        
                        let dbThumbnail: ImageData = (entityManager?.entityCreator.imageData())!
                        dbThumbnail.data = thumbnailData;
                        dbThumbnail.width = NSNumber(value: Float(image.size.width))
                        dbThumbnail.height = NSNumber(value: Float(image.size.height))
                        
                        let message: ImageMessage = (entityManager?.entityCreator.imageMessage(for: conversation))!
                        message.thumbnail = dbThumbnail;
                        message.image = dbImage;
                        message.date = date
                        message.sender = conversation?.contact
                        message.sent = true
                        message.delivered = true
                        message.read = true
                        message.remoteSentDate = Date()
                    }
                }
            })
            
        }
    }
    
    /**
     Adding 160 contacts with Threema ID's (./Resources/test_ids.txt) for testing.
    */
    func testLoadContacts() {
        let testBundle: Bundle = Bundle(for: DbLoadTests.self)
        if let filePath = testBundle.path(forResource: "test_ids", ofType: "txt") {
            let queue = DispatchQueue.global()
            let semaphore = DispatchSemaphore(value: 0)

            var pks = [String: Data]()

            do {
                var fetchIdentities = [String]()
                
                let ids = try String(contentsOfFile: filePath, encoding: .utf8)
                for id in ids.components(separatedBy: .newlines) {
                    if id.count > 0 {
                        fetchIdentities.append(id)
                    }
                }
                
                queue.async {
                    let api = ServerAPIConnector()
                    api.fetchBulkIdentityInfo(fetchIdentities, onCompletion: { (identities, publicKeys, featureMasks, states, types) in
                        
                        for index in 0..<(identities!.count-1) {
                            pks[identities![index] as! String] = Data(base64Encoded: publicKeys![index] as! String)
                        }
                            
                        semaphore.signal()
                    }) { (error) in
                        print(error?.localizedDescription)

                        semaphore.signal()
                    }
                }
            }
            catch {
                print(error)
            }

            semaphore.wait()

            let entityManager = EntityManager(forBackgroundProcess: false)

            for pk in pks {
                print("add id: \(pk.key)")
                
                entityManager?.performSyncBlockAndSafe({
                    if let contact = entityManager?.entityCreator.contact() {
                        contact.identity = pk.key
                        contact.verificationLevel = 0
                        contact.publicNickname = pk.key
                        contact.hidden = 0
                        contact.workContact = 0
                        contact.publicKey = pk.value
                    }
                })
            }
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testLoadImageFileMessages() {
        var conversation: Conversation? = nil
        
        let entityManager = EntityManager(forBackgroundProcess: false)
        entityManager?.performSyncBlockAndSafe({
            if let contact = entityManager?.entityFetcher?.contact(forId: "ECHOECHO") {
                conversation = (entityManager?.conversation(for: contact, createIfNotExisting: true))!
            }
        })
        
        for i in 0..<1000 {
            print("\(i)/1000")
            let testBundle: Bundle = Bundle(for: DbLoadTests.self)
            let testImageUrl = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
            let testImageData = try? Data(contentsOf: testImageUrl!)
            
            loadImage(with: testImageData!, conversation!, entityManager!)
        }
    }
    
    func loadImage(with imageData : Data, _ conversation : Conversation, _ entityManager : EntityManager) {
        
        entityManager.performSyncBlockAndSafe({
            let dbFile: FileData = (entityManager.entityCreator.fileData())!
            dbFile.data = imageData
            
            let thumbnailFile : ImageData = entityManager.entityCreator.imageData()!
            thumbnailFile.data = MediaConverter.getThumbnailFor(UIImage(data: imageData))?.jpegData(compressionQuality: 1.0)
            
            let message: FileMessage = (entityManager.entityCreator.fileMessage(for: conversation))!
            message.data = dbFile
            message.thumbnail = thumbnailFile
            message.fileName = "Bild.jpeg"
            message.fileSize = NSNumber(integerLiteral: dbFile.data!.count)
            message.mimeType = "image/jpeg"
            message.type = NSNumber(integerLiteral: 1);
            message.date = Date(timeIntervalSinceReferenceDate: TimeInterval(-1 * Int.random(in: 0...223456789)))
            message.sender = conversation.contact
            message.sent = true
            message.delivered = true
            message.read = true
            message.remoteSentDate = Date()
        })
    }

}
