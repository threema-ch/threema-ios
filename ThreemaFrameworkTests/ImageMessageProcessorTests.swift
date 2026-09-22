import PromiseKit
import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class ImageMessageProcessorTests: XCTestCase {

    enum ImageMessageProcessorTestsError: Error {
        case urlIsNil
    }

    private var databasePreparer: TestDatabasePreparer!
    private var entityManager: EntityManager!
    private var conversation: ConversationEntity!

    private let baseURLString = "https://example.com"
    private let encryptionKey = BytesUtility.generateBlobEncryptionKey()

    private let testBlobID = BytesUtility.generateBlobID()
    private lazy var fullImageData: Data = try! Data(
        contentsOf: Bundle(
            for: ImageMessageProcessorTests.self
        ).url(
            forResource: "Bild-1-1",
            withExtension: "jpg"
        )!
    )
    private lazy var encryptedImageData: Data = NaClCrypto.shared().symmetricEncryptData(
        fullImageData,
        withKey: encryptionKey,
        nonce: ThreemaProtocol.nonce01
    )

    // MARK: - Lifecycle

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

        entityManager = testDatabase.entityManager
    }

    // MARK: - Tests

    @MainActor
    func testDownloadImageStoresFullImageDataAndSeparateThumbnail() async throws {
        // Arrange
        var imageMessageEntity: ImageMessageEntity!

        databasePreparer.save {
            imageMessageEntity = databasePreparer.createImageMessageEntity(
                conversation: conversation,
                image: nil,
                thumbnail: nil,
                isOwn: false,
                sender: nil,
                remoteSentDate: Date()
            )
            imageMessageEntity.imageBlobID = testBlobID
            imageMessageEntity.encryptionKey = encryptionKey
        }

        let expectationData = expectation(description: "Image data download")
        let dataURL = try await blobURL(with: testBlobID)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedImageData, dataResponse, nil),
            {
                expectationData.fulfill()
            }
        )

        let expectationDone = expectation(description: "Image data download done")
        let doneURL = try await doneURL(with: testBlobID)
        let doneResponse = HTTPURLResponse(url: doneURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURL] = (
            (nil, nil, doneResponse, nil),
            {
                expectationDone.fulfill()
            }
        )

        let processor = ImageMessageProcessor(
            blobDownloader: BlobDownloader(
                blobURL: BlobURL(
                    serverConnector: ServerConnectorMock(),
                    userSettings: UserSettingsMock(),
                    serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString)
                ),
                sessionManager: URLSessionManager(with: TestSessionProvider())
            ),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            entityManager: entityManager
        )

        let expectationProcessed = expectation(description: "Image download processed")

        // Act
        processor.downloadImage(
            imageMessageID: imageMessageEntity.id,
            in: imageMessageEntity.conversation.objectID,
            imageBlobID: testBlobID,
            origin: imageMessageEntity.blobOrigin,
            imageBlobEncryptionKey: encryptionKey,
            imageBlobNonce: nil,
            senderPublicKey: nil,
            maxBytesToDecrypt: Int.max
        )
        .done {
            expectationProcessed.fulfill()
        }
        .catch { error in
            XCTFail("Image download failed: \(error)")
        }

        await fulfillment(of: [expectationData, expectationDone, expectationProcessed], timeout: 30)

        // Assert
        let imageEntity = try XCTUnwrap(imageMessageEntity.image)
        let thumbnailEntity = try XCTUnwrap(imageMessageEntity.thumbnail)

        XCTAssertEqual(imageEntity.data, fullImageData)
        XCTAssertNotEqual(imageEntity.objectID, thumbnailEntity.objectID)
        XCTAssertNotEqual(imageEntity.data, thumbnailEntity.data)

        let fullImage = try XCTUnwrap(UIImage(data: fullImageData))
        XCTAssertEqual(Int16(fullImage.size.width), imageEntity.width)
        XCTAssertEqual(Int16(fullImage.size.height), imageEntity.height)
    }

    // MARK: - Helper

    private func blobURL(with blobID: Data) async throws -> URL {
        let blobURL = BlobURL(
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString)
        )
        return try await withCheckedThrowingContinuation { continuation in
            blobURL.download(blobID: blobID, origin: .public) { url, _ in
                guard let url else {
                    continuation.resume(throwing: ImageMessageProcessorTestsError.urlIsNil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }

    private func doneURL(with blobID: Data) async throws -> URL {
        let blobURL = BlobURL(
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString)
        )
        guard let url = try await blobURL.done(blobID: blobID, origin: .public) else {
            throw ImageMessageProcessorTestsError.urlIsNil
        }
        return url
    }
}
