import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BlobDataStateTests: XCTestCase {
    
    private var databasePreparer: TestDatabasePreparer!
    private var conversation: ConversationEntity!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
    }
    
    // MARK: - thumbnailState
    
    private func thumbnailTestImageDataEntity() -> ImageDataEntity {
        let testBundle = Bundle(for: BlobDataStateTests.self)
        let testImageURL = testBundle.url(forResource: "Bild-1-1-thumbnail", withExtension: "jpg")!
        let testImageData = try! Data(contentsOf: testImageURL)
        
        return databasePreparer.createImageDataEntity(
            data: testImageData,
            height: 512,
            width: 384
        )
    }
    
    // MARK: Incoming

    func testFileMessageThumbnailIncomingStateRemote() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                isOwn: false
            )
        }
        
        XCTAssertEqual(.incoming(.remote(error: nil)), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailIncomingStateProcessed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.thumbnail = thumbnailTestImageDataEntity()
        }
        
        XCTAssertEqual(.incoming(.processed), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailIncomingStateNoThumbnail() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
        }
        
        XCTAssertEqual(.incoming(.noData(.noThumbnail)), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailIncomingStateNoKeyFatalError() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                blobThumbnailID: BytesUtility.generateBlobID()
            )
        }
        
        XCTAssertEqual(.incoming(.fatalError(.noEncryptionKey)), fileMessageEntity.thumbnailState)
    }
    
    // MARK: Outgoing
    
    func testFileMessageThumbnailOutgoingStatePendingUploadFailed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                thumbnail: thumbnailTestImageDataEntity(),
                isOwn: true
            )
            fileMessageEntity.sendFailed = NSNumber(booleanLiteral: true)
        }
        
        XCTAssertEqual(.outgoing(.pendingUpload(error: .uploadFailed)), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailOutgoingStatePendingUploadFailedWithExistingProgess() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0),
                thumbnail: thumbnailTestImageDataEntity(),
                isOwn: true
            )
            fileMessageEntity.sendFailed = NSNumber(booleanLiteral: true)
        }

        XCTAssertEqual(.outgoing(.pendingUpload(error: .uploadFailed)), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailOutgoingStatePendingUploadNotUploading() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                thumbnail: thumbnailTestImageDataEntity(),
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.pendingUpload(error: .uploadFailed)), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailOutgoingStateUploadingWithZeroProgress() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0),
                thumbnail: thumbnailTestImageDataEntity(),
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.uploading), fileMessageEntity.thumbnailState)
    }

    func testFileMessageThumbnailOutgoingStateUploading() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0.8),
                thumbnail: thumbnailTestImageDataEntity(),
                isOwn: true
            )
        }

        XCTAssertEqual(.outgoing(.uploading), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailOutgoingStateRemote() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                blobThumbnailID: BytesUtility.generateBlobID(),
                isOwn: true
            )
            fileMessageEntity.thumbnail = databasePreparer.createImageDataEntity(data: Data([0]), height: 1, width: 1)
        }

        XCTAssertEqual(.outgoing(.remote), fileMessageEntity.thumbnailState)
    }
    
    func testFileMessageThumbnailOutgoingStateNoThumbnail() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                isOwn: true
            )
        }

        XCTAssertEqual(.outgoing(.noData(.noThumbnail)), fileMessageEntity.thumbnailState)
    }
    
    // MARK: - dataState
    
    // MARK: Incoming
    
    func testFileMessageDataIncomingStateRemote() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID()
            )
        }
        
        XCTAssertEqual(.incoming(.remote(error: nil)), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateRemoteWithError() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID()
            )
            fileMessageEntity.sendFailed = NSNumber(booleanLiteral: true)
        }
        
        XCTAssertEqual(.incoming(.remote(error: .downloadFailed)), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateDownloading() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                progress: NSNumber(floatLiteral: 0.4)
            )
        }
        
        XCTAssertEqual(.incoming(.downloading), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateProcessing() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 1)
            )
        }
        
        XCTAssertEqual(.incoming(.processing), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateProcessed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))
            
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                data: fileDataEntity
            )
        }
        
        XCTAssertEqual(.incoming(.processed), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateFatalErrorNoEncryptionKey() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                blobID: BytesUtility.generateBlobID()
            )
        }
        
        XCTAssertEqual(.incoming(.fatalError(.noEncryptionKey)), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataIncomingStateDeleted() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobThumbnailID: BytesUtility.generateBlobID()
            )
        }
        
        XCTAssertEqual(.incoming(.noData(.deleted)), fileMessageEntity.dataState)
    }
    
    // MARK: Outgoing
    
    func testFileMessageDataOutgoingPendingUploadNotUploading() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                data: fileDataEntity,
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.pendingUpload(error: .uploadFailed)), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataOutgoingPendingUploadFailed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0),
                data: fileDataEntity,
                isOwn: true
            )
            fileMessageEntity.sendFailed = NSNumber(booleanLiteral: true)
        }
        
        XCTAssertEqual(.outgoing(.pendingUpload(error: .uploadFailed)), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataOutgoingUploadingWithZeroProgress() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0),
                data: fileDataEntity,
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.uploading), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataOutgoingUploading() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                progress: NSNumber(floatLiteral: 0.8),
                data: fileDataEntity,
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.uploading), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataOutgoingStateRemote() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                isOwn: true
            )
            fileMessageEntity.data = databasePreparer.createFileDataEntity(data: Data([0]))
        }
        
        XCTAssertEqual(.outgoing(.remote), fileMessageEntity.dataState)
    }
    
    func testFileMessageDataOutgoingDeleted() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                isOwn: true
            )
        }
        
        XCTAssertEqual(.outgoing(.noData(.deleted)), fileMessageEntity.dataState)
    }

    func testFileMessageDataOutgoingStatePendingDownload() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                isOwn: true
            )
        }

        XCTAssertEqual(.outgoing(.pendingDownload(error: nil)), fileMessageEntity.dataState)
    }

    func testFileMessageDataOutgoingStateDownloading() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                progress: NSNumber(floatLiteral: 0.0),
                isOwn: true
            )
        }

        XCTAssertEqual(.outgoing(.downloading), fileMessageEntity.dataState)
    }
}
