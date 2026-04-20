import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class ImageDataEntityTests: XCTestCase {
    
    // MARK: - Properties

    private let testBundle = Bundle(for: ImageDataEntityTests.self)
    
    // MARK: - Tests

    func testCreationFull() throws {
        try creationTestFull(encrypted: false)
    }
    
    func testCreationEncrypted() throws {
        try creationTestFull(encrypted: true)
    }
    
    private func creationTestFull(encrypted: Bool) throws {
        // Arrange
        let testDatabase = TestDatabase(encrypted: encrypted)
        let entityManager = testDatabase.entityManager

        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-4", withExtension: "png"))
        let data = try XCTUnwrap(Data(contentsOf: testImageURL))
        let image = try XCTUnwrap(UIImage(data: data))
       
        // Act
        let imageMessageEntity = entityManager.performAndWaitSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            
            return ImageMessageEntity(
                context: testDatabase.context.main,
                id: BytesUtility.generateMessageID(),
                isOwn: true,
                conversation: conversation
            )
        }
        
        // Count only encrypt calls while saving `ImageDataEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let imageDataEntity = entityManager.performAndWaitSave {
            ImageDataEntity(
                context: testDatabase.context.main,
                data: data,
                height: Int16(image.size.height),
                width: Int16(image.size.width),
                message: imageMessageEntity
            )
        }
        
        let fetchedImageDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageDataEntity.objectID) as? ImageDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedImageDataEntity.data)
        XCTAssertEqual(Int16(image.size.height), fetchedImageDataEntity.height)
        XCTAssertEqual(Int16(image.size.width), fetchedImageDataEntity.width)
        XCTAssertEqual(image.pngData(), fetchedImageDataEntity.uiImage()?.pngData())
        XCTAssertEqual(imageMessageEntity.objectID, fetchedImageDataEntity.message?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 3)

            // Test faulting
            testDatabase.context.main.refresh(fetchedImageDataEntity, mergeChanges: false)

            XCTAssertEqual(data, fetchedImageDataEntity.data)
            XCTAssertEqual(Int16(image.size.height), fetchedImageDataEntity.height)
            XCTAssertEqual(Int16(image.size.width), fetchedImageDataEntity.width)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 3)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 3)
        }
        else {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 0)
        }
    }

    func testCreationMinimal() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-4", withExtension: "png"))
        let data = try XCTUnwrap(Data(contentsOf: testImageURL))
        let image = try XCTUnwrap(UIImage(data: data))
       
        // Act
        let imageDataEntity = entityManager.performAndWaitSave {
            ImageDataEntity(
                context: testDatabase.context.main,
                data: data,
                height: Int16(image.size.height),
                width: Int16(image.size.width),
            )
        }
        
        let fetchedImageDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageDataEntity.objectID) as? ImageDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedImageDataEntity.data)
        XCTAssertEqual(Int16(image.size.height), fetchedImageDataEntity.height)
        XCTAssertEqual(Int16(image.size.width), fetchedImageDataEntity.width)
        XCTAssertEqual(image.pngData(), fetchedImageDataEntity.uiImage()?.pngData())
    }
}
