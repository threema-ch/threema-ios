import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BlobDataDisplayTests: XCTestCase {

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
    
    // MARK: - blobDisplayState
    
    func testFileMessageDisplayStateRemote() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                blobThumbnailID: BytesUtility.generateBlobID()
            )
        }

        XCTAssertEqual(.remote, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateDownloading() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.25
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                progress: NSNumber(floatLiteral: Double(progress))
            )
        }

        XCTAssertEqual(.downloading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateProcessed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                data: fileDataEntity
            )
        }

        XCTAssertEqual(.processed, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStatePending() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                data: fileDataEntity,
                isOwn: true
            )
        }

        XCTAssertEqual(.pending, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStatePendingWithThumbnail() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                data: fileDataEntity,
                thumbnail: databasePreparer.createImageDataEntity(data: Data(count: 1), height: 1, width: 1),
                isOwn: true
            )
        }

        XCTAssertEqual(.pending, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploading() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.84
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileDataEntity,
                isOwn: true
            )
        }

        XCTAssertEqual(.uploading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploadingThumbnailWithUploadedData() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.1
        
        func thumbnailTestImageData() -> ImageDataEntity {
            let testBundle = Bundle(for: BlobDataStateTests.self)
            let testImageURL = testBundle.url(forResource: "Bild-1-1-thumbnail", withExtension: "jpg")!
            let testImageData = try! Data(contentsOf: testImageURL)
            
            return databasePreparer.createImageDataEntity(
                data: testImageData,
                height: 512,
                width: 384
            )
        }
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileDataEntity,
                thumbnail: thumbnailTestImageData(),
                isOwn: true
            )
        }

        XCTAssertEqual(.uploading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploadingWithUploadedThumbnail() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.536
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileDataEntity,
                thumbnail: databasePreparer.createImageDataEntity(data: Data(count: 1), height: 1, width: 1),
                isOwn: true
            )
        }

        XCTAssertEqual(.uploading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploaded() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileDataEntity = databasePreparer.createFileDataEntity(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                data: fileDataEntity,
                thumbnail: databasePreparer.createImageDataEntity(data: Data(count: 1), height: 1, width: 1),
                isOwn: true
            )
        }

        XCTAssertEqual(.uploaded, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateDataDeleted() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey()
            )
        }

        XCTAssertEqual(.dataDeleted, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateOutgoingDataDeleted() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                isOwn: true
            )
        }

        XCTAssertEqual(.dataDeleted, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateFileNotFound() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation
            )
        }

        XCTAssertEqual(.fileNotFound, fileMessageEntity.blobDisplayState)
    }

    func testFileMessageDisplayStatePendingDownloadThumbnail() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                blobThumbnailID: BytesUtility.generateBlobID(),
                isOwn: true
            )
        }

        XCTAssertEqual(.remote, fileMessageEntity.blobDisplayState)
    }

    func testFileMessageDisplayStatePendingDownloadData() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateBlobEncryptionKey(),
                blobID: BytesUtility.generateBlobID(),
                isOwn: true
            )
        }

        XCTAssertEqual(.remote, fileMessageEntity.blobDisplayState)
    }
}
