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

import XCTest
@testable import ThreemaFramework

class EntityCreatorTests: XCTestCase {

    private let testBundle = Bundle(for: EntityCreatorTests.self)
    private var context: NSManagedObjectContext!
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!
    private var entityManager: EntityManager!
    private var businessInjector: FrameworkInjectorProtocol!
    
    override func setUp() {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, context, backgroundManagedObjectContext) = DatabasePersistentContext.devNullContext()
                
        databasePreparer = DatabasePreparer(context: context)
        
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
        
        let databaseContext = DatabaseContext(
            mainContext: context,
            backgroundContext: backgroundManagedObjectContext
        )
        entityManager = EntityManager(databaseContext: databaseContext)
        
        businessInjector = BusinessInjectorMock(entityManager: entityManager)
    }

    func testCreateFileMessageEntityImage() async throws {
        
        // Arrange
        let imageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageData = try XCTUnwrap(Data(contentsOf: imageURL))
        let uti = try XCTUnwrap(ImageURLSenderItemCreator.getUTI(for: imageData) as? String)
        let senderItem = try XCTUnwrap(ImageURLSenderItemCreator().senderItem(from: imageData, uti: uti))
        
        let correlationID = "TestCorrelationID"
        let webRequestID = "TestWebRequestID"
        // Act
        var createdFileMessageEntity: FileMessageEntity?

        entityManager.performSyncBlockAndSafe {
            createdFileMessageEntity = try? self.entityManager.entityCreator.createFileMessageEntity(
                for: senderItem,
                in: self.conversation,
                with: .public,
                correlationID: correlationID,
                webRequestID: webRequestID
            )
        }
               
        // Assert
        let fileMessageEntity = try XCTUnwrap(createdFileMessageEntity)
        
        XCTAssertEqual(fileMessageEntity.width, NSNumber(floatLiteral: senderItem.getWidth()))
        XCTAssertEqual(fileMessageEntity.height, NSNumber(floatLiteral: senderItem.getHeight()))

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            senderItem: senderItem,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }
    
    // TODO: (IOS-3875) Timeout
    func testCreateFileMessageEntityVideo() async throws {
        
        // Arrange
        let videoURLSenderItemCreator = VideoURLSenderItemCreator()
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let senderItem = try XCTUnwrap(videoURLSenderItemCreator.senderItem(from: testVideoURL))

        let correlationID = "TestCorrelationID"
        let webRequestID = "TestWebRequestID"
        
        // Act
        var createdFileMessageEntity: FileMessageEntity?
        
        entityManager.performSyncBlockAndSafe {
            createdFileMessageEntity = try? self.entityManager.entityCreator.createFileMessageEntity(
                for: senderItem,
                in: self.conversation,
                with: .public,
                correlationID: correlationID,
                webRequestID: webRequestID
            )
        }
       
        // Assert
        let fileMessageEntity = try XCTUnwrap(createdFileMessageEntity)
        
        XCTAssertEqual(fileMessageEntity.width, NSNumber(floatLiteral: senderItem.getWidth()))
        XCTAssertEqual(fileMessageEntity.height, NSNumber(floatLiteral: senderItem.getHeight()))
        XCTAssertEqual(fileMessageEntity.duration, NSNumber(floatLiteral: senderItem.getDuration()))

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            senderItem: senderItem,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }
    
    func testCreateFileMessageEntityAudio() async throws {
        
        // Arrange
        let audioURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))
        let senderItem = try XCTUnwrap(URLSenderItemCreator.getSenderItem(for: audioURL))

        let correlationID = "TestCorrelationID"
        let webRequestID = "TestWebRequestID"
        
        // Act
        var createdFileMessageEntity: FileMessageEntity?
        
        entityManager.performSyncBlockAndSafe {
            createdFileMessageEntity = try? self.entityManager.entityCreator.createFileMessageEntity(
                for: senderItem,
                in: self.conversation,
                with: .public,
                correlationID: correlationID,
                webRequestID: webRequestID
            )
        }
       
        // Assert
        let fileMessageEntity = try XCTUnwrap(createdFileMessageEntity)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            senderItem: senderItem,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }
    
    func testCreateFileMessageEntityFile() async throws {
        
        // Arrange
        let fileURL = try XCTUnwrap(testBundle.url(forResource: "Test", withExtension: "pdf"))
        let senderItem = try XCTUnwrap(URLSenderItemCreator.getSenderItem(for: fileURL))

        let correlationID = "TestCorrelationID"
        let webRequestID = "TestWebRequestID"
        
        // Act
        var createdFileMessageEntity: FileMessageEntity?
        
        entityManager.performSyncBlockAndSafe {
            createdFileMessageEntity = try? self.entityManager.entityCreator.createFileMessageEntity(
                for: senderItem,
                in: self.conversation,
                with: .public,
                correlationID: correlationID,
                webRequestID: webRequestID
            )
        }
       
        // Assert
        let fileMessageEntity = try XCTUnwrap(createdFileMessageEntity)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            senderItem: senderItem,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }
    
    // MARK: - Private Functions
    
    private func generalFileMessageAssertions(
        fileMessageEntity: FileMessageEntity,
        senderItem: URLSenderItem,
        correlationID: String,
        webRequestID: String
    ) {
        XCTAssertEqual(fileMessageEntity.blobData, senderItem.getData())
        XCTAssertEqual(fileMessageEntity.mimeType, senderItem.getMimeType())
        XCTAssertEqual(fileMessageEntity.caption, senderItem.caption)
        XCTAssertEqual(fileMessageEntity.fileName, senderItem.getName())
        XCTAssertEqual(fileMessageEntity.fileSize, NSNumber(integerLiteral: senderItem.getData().count))
        XCTAssertEqual(fileMessageEntity.type, senderItem.renderType)
        XCTAssertEqual(fileMessageEntity.correlationID, correlationID)
        XCTAssertEqual(fileMessageEntity.webRequestID, webRequestID)
    }
}
