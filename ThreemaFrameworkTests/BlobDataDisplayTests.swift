//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class BlobDataDisplayTests: XCTestCase {
    
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        
        databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                marked: false,
                typing: false,
                unreadMessageCount: 0,
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
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
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
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                progress: NSNumber(floatLiteral: Double(progress))
            )
        }

        XCTAssertEqual(.downloading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateProcessed() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                data: fileData
            )
        }

        XCTAssertEqual(.processed, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStatePending() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                data: fileData,
                isOwn: true
            )
        }

        XCTAssertEqual(.pending, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStatePendingWithThumbnail() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                data: fileData,
                isOwn: true
            )
        }

        XCTAssertEqual(.pending, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploading() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.84
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileData,
                isOwn: true
            )
        }

        XCTAssertEqual(.uploading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploadingThumbnailWithUploadedData() {
        var fileMessageEntity: FileMessageEntity!
        let progress: Float = 0.1
        
        func thumbnailTestImageData() -> ImageData {
            let testBundle = Bundle(for: BlobDataStateTests.self)
            let testImageURL = testBundle.url(forResource: "Bild-1-1-thumbnail", withExtension: "jpg")!
            let testImageData = try! Data(contentsOf: testImageURL)
            
            return databasePreparer.createImageData(
                data: testImageData,
                height: 512,
                width: 384
            )
        }
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileData,
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
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                progress: NSNumber(floatLiteral: Double(progress)),
                data: fileData,
                isOwn: true
            )
        }

        XCTAssertEqual(.uploading(progress: progress), fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateUploaded() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            let fileData = databasePreparer.createFileData(data: Data(count: 10))

            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
                blobID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                blobThumbnailID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!,
                data: fileData,
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
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
            )
        }

        XCTAssertEqual(.dataDeleted, fileMessageEntity.blobDisplayState)
    }
    
    func testFileMessageDisplayStateOutgoingDataDeleted() {
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!,
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
}
