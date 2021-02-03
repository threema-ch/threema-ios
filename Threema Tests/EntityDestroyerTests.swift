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
import CoreData

class EntityDestroyerTests: XCTestCase {

    var objCnx: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        self.objCnx = TestDatabasePersistentManager.devNullContext()

        // Setup DB for testing, insert 10 video messages
        let testEntityManager = TestDatabaseEntityManager(context: self.objCnx)
        testEntityManager.save {
            let conversation = testEntityManager.createConversation()
            let thumbnail = testEntityManager.createImageData()
            
            let userCalendar = Calendar.current
            let toDate = Date()
            
            for index in 1...10 {
                var addDate = DateComponents()
                addDate.day = index * -1
                addDate.hour = 1

                let date = userCalendar.date(byAdding: addDate, to: toDate)
                testEntityManager.createVideoMessage(conversation: conversation, thumbnail: thumbnail, videoData: testEntityManager.createVideoData(), date: date)
            }
        }

        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeleteMedias() {
        let deleteTests = [
            // days diff, expected count of deleted media
            [-2, 8],
            [nil, 2]
        ]
        
        let userCalendar = Calendar.current
        
        for deleteTest in deleteTests {
            var olderThan: Date? = nil
            if let daysAdd = deleteTest[0] {
                olderThan = userCalendar.date(byAdding: .day, value: daysAdd, to: Date())
            }
            
            let ed = EntityDestroyer(managedObjectContext: self.objCnx)
            let count = ed.deleteMedias(olderThan: olderThan)
            
            XCTAssertEqual(count, deleteTest[1]!, "not expected count of deleted medias")
        }
    }
    
    func testDeleteMessages() {
        let deleteTests = [
            // days diff, expected count of deleted media
            [-2, 8],
            [nil, 2]
        ]
        
        let userCalendar = Calendar.current
        
        for deleteTest in deleteTests {
            var olderThan: Date? = nil
            if let daysAdd = deleteTest[0] {
                olderThan = userCalendar.date(byAdding: .day, value: daysAdd, to: Date())
            }
            
            let ed = EntityDestroyer(managedObjectContext: self.objCnx)
            let count = ed.deleteMessages(olderThan: olderThan)
            
            XCTAssertEqual(count, deleteTest[1]!, "not expected count of deleted messages")
        }
    }

    class TestDatabasePersistentManager {
        
        /**
         Context in memory, doesn't work with NSBatch... commands (use devNullContext)
         
         - Returns:
            DB context for testing
        */
        static func inMemoryContext() -> NSManagedObjectContext {
            let modelURL = BundleUtil.url(forResource:"ThreemaData", withExtension: "momd")
            let managedObjectContext = NSManagedObjectModel(contentsOf: modelURL!)
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectContext!)
            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            }
            catch {
                fatalError("Adding in memory persistent store failed")
            }
            
            let context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
            context.persistentStoreCoordinator = persistentStoreCoordinator
            
            return context
        }
        
        /**
         Context stored data to /dev/null, works with NSBatch... commands
         
         - Returns:
            DB context for testing
        */
        static func devNullContext() -> NSManagedObjectContext {
            let modelURL = BundleUtil.url(forResource:"ThreemaData", withExtension: "momd")
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)
            let container = NSPersistentContainer(name: "TestData", managedObjectModel: managedObjectModel!)
            container.persistentStoreDescriptions[0].url = URL(fileURLWithPath: "/dev/null")
            container.loadPersistentStores { (description, error) in
                XCTAssertNil(error)
            }
            
            return container.viewContext
        }
    }
    
    class TestDatabaseEntityManager {
        private let objCnx: NSManagedObjectContext
        
        required init(context: NSManagedObjectContext) {
            self.objCnx = context
        }
        
        /**
         Save data modifications on DB.
         
         - Parameters:
            - dbModificationAction: Closure with data modifications
        */
        func save(dbModificationAction: () -> Void) {
            do {
                dbModificationAction()
                
                try self.objCnx.save()
            }
            catch {
                print(error)
                XCTFail("Could not generate test data.")
            }
        }
        
        func createConversation() -> Conversation {
            let conversation = createEntity(objectType: Conversation.self)
            conversation.marked = false
            conversation.typing = false
            conversation.unreadMessageCount = 0
            return conversation
        }
        
        func createImageData() -> ImageData {
            let imageData = createEntity(objectType: ImageData.self)
            imageData.data = Data([22])
            imageData.height = 22
            imageData.width = 22
            return imageData
        }
        
        func createVideoData() -> VideoData {
            let videoData = createEntity(objectType: VideoData.self)
            videoData.data = Data([1])
            return videoData
        }
        
        func createVideoMessage(conversation: Conversation, thumbnail: ImageData, videoData: VideoData?, date: Date?) -> VideoMessage {
            let videoMessage = createEntity(objectType: VideoMessage.self)
            videoMessage.date = date
            videoMessage.delivered = 1
            videoMessage.id = Data([11])
            videoMessage.isOwn = true
            videoMessage.read = true
            videoMessage.sent = true
            videoMessage.userack = false
            videoMessage.conversation = conversation
            videoMessage.thumbnail = thumbnail
            videoMessage.duration = 10
            videoMessage.video = videoData
            videoMessage.remoteSentDate = Date()
            return videoMessage
        }
        
        private func createEntity<T: NSManagedObject>(objectType: T.Type) -> T {
            var entityName: String
            
            if objectType is Conversation.Type {
                entityName = "Conversation"
            }
            else if objectType is ImageData.Type {
                entityName = "ImageData"
            }
            else if objectType is VideoData.Type {
                entityName = "VideoData"
            }
            else if objectType is VideoMessage.Type {
                entityName = "VideoMessage"
            }
            else {
                fatalError("objects type not defined")
            }
            
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: self.objCnx) as! T
        }
    }
}
