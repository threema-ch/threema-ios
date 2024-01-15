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

import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

class BlobManagerTests: XCTestCase {
    
    enum BlobManagerTestsError: Error {
        case urlIsNil
        case noData
    }

    enum Direction {
        case incoming, outgoing
    }

    private let testBundle = Bundle(for: BlobManagerTests.self)
    private var context: NSManagedObjectContext!
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!
    private var groupConversation: Conversation!
    private var entityManager: EntityManager!
    private var blobManager: BlobManager!
    private let myIdentityStoreMock = MyIdentityStoreMock()
    private let baseURLString = "https://example.com"
    private let encryptionKey = BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
    
    private let testThumbnailID = "546573745468756d62".data(using: .ascii)!
    private let testThumbnailData = try! Data(
        contentsOf: Bundle(
            for: BlobManagerTests.self
        ).url(
            forResource: "Bild-1-1-thumbnail",
            withExtension: "jpg"
        )!
    )
    private lazy var encryptedThumbnailData: Data = NaClCrypto.shared().symmetricEncryptData(
        testThumbnailData,
        withKey: encryptionKey,
        nonce: ThreemaProtocol.nonce02
    )
    
    private let testBlobID = "54657374426c6f62".data(using: .ascii)!
    private let testBlobData = "This is test blob data.".data(using: .utf8)!
    private lazy var encryptedBlobData: Data = NaClCrypto.shared().symmetricEncryptData(
        testBlobData,
        withKey: encryptionKey,
        nonce: ThreemaProtocol.nonce01
    )
    
    // MARK: - Lifecycle
    
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
            
            groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
        }
        
        let databaseContext = DatabaseContext(
            mainContext: context,
            backgroundContext: backgroundManagedObjectContext
        )
        
        entityManager = EntityManager(databaseContext: databaseContext, myIdentityStore: myIdentityStoreMock)
        
        blobManager = BlobManager(
            entityManager: entityManager,
            sessionManager: URLSessionManager(with: TestSessionProvider()),
            serverConnector: ServerConnectorMock(connectionState: .loggedIn),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString),
            userSettings: UserSettingsMock()
        )
    }
    
    override func setUpWithError() throws { }
    
    // MARK: - Incoming Tests
    
    @MainActor
    func testIncomingDataNoThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                isOwn: false
            )
        }
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, dataResponse),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDone = expectation(description: "Basic Incoming Blob Sync Done")
        let doneURL = try await doneURL(with: baseURLString, and: blobID)
        let doneResponse = HTTPURLResponse(url: doneURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURL] = (
            (nil, encryptedBlobData, doneResponse),
            {
                expectationDone.fulfill()
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationData, expectationDone], timeout: 50)
        
        // Assert
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualBlobData, testBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingDataWithThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let expectationDoneThumbnail = expectation(description: "Basic Incoming Blob Thumbnail Done")
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData], timeout: 50)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let thumbnail = try XCTUnwrap(fileMessageEntity.thumbnail)
        let loadedThumbnailImage = try XCTUnwrap(UIImage(data: testThumbnailData))
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(loadedThumbnailImage.size.width as NSNumber, thumbnail.width)
        XCTAssertEqual(loadedThumbnailImage.size.height as NSNumber, thumbnail.height)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    // TODO: (IOS-3875) Timeout
    @MainActor
    func testIncomingDataWithThumbnailNoDone() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: groupConversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                XCTFail("Done must not be called")
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                XCTFail("Done must no be called")
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationData], timeout: 60)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingDataRetryNoThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                isOwn: false
            )
        }
        
        entityManager.performSyncBlockAndSafe {
            fileMessageEntity.blobError = true
        }
        
        let expectationData = expectation(description: "Basic Incoming Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let response = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDone = expectation(description: "Basic Incoming Sync Done")
        let doneURL = try await doneURL(with: baseURLString, and: blobID)
        let doneResponse = HTTPURLResponse(url: doneURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURL] = (
            (nil, encryptedBlobData, doneResponse),
            {
                expectationDone.fulfill()
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationData, expectationDone], timeout: 50)
        
        // Assert
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingNoActionNeeded() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                isOwn: false
            )
        }
        
        entityManager.performSyncBlockAndSafe {
            fileMessageEntity.blobThumbnail = self.testBlobData
            fileMessageEntity.blobData = self.testBlobData
        }
        
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, nil, nil),
            {
                XCTFail("This should not be called since, we already have all the data of the file message.")
            }
        )
        
        let blobURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[blobURL] = (
            (nil, nil, nil),
            {
                XCTFail("This should not be called since, we already have all the data of the file message.")
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // Assert
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingNoIDThrows() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                blobThumbnailID: nil,
                isOwn: false
            )
        }
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(
            try await blobManager.syncBlobsThrows(for: fileMessageEntity.objectID)
        ) { error in
            XCTAssertEqual(error as! BlobManagerError, BlobManagerError.noID)
        }
    }
    
    // MARK: - Outgoing Tests
    
    @MainActor
    func testOutgoingDataNoThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileData = databasePreparer.createFileData(data: testBlobData)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                data: fileData,
                thumbnail: nil,
                isOwn: true
            )
        }
        
        let expectation = expectation(description: "Basic Incoming Sync")
        let url = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[url] = (
            (nil, testBlobID, response),
            {
                expectation.fulfill()
            }
        )
        
        // Act
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectation], timeout: 50)
        
        // Assert
        let receivedBlobID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobIdentifier))
        
        XCTAssertEqual(testBlobID, receivedBlobID)
    }
    
    @MainActor
    func testOutGoingDataWithThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileData = databasePreparer.createFileData(data: testBlobData)
        let thumbnailData = databasePreparer.createImageData(data: testThumbnailData, height: 10, width: 10)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                blobThumbnailID: nil,
                data: fileData,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }
        
        let expectationData = expectation(description: "Basic Incoming Sync")
        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Since the upload urls do not differentiate we wait for two calls of the closure before fulfilling and we
        // check below for testBlobID again.
        var counter = 0
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData),
            { counter += 1
                if counter == 2 {
                    expectationData.fulfill()
                }
            }
        )
        
        // Act
        do {
            try await blobManager.syncBlobsThrows(for: fileMessageEntity.objectID)
        }
        catch {
            XCTAssertEqual(error as! BlobManagerError, BlobManagerError.sendingFailed)
        }
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationData], timeout: 50)
        
        // Assert
        let receivedThumbnailID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobThumbnailIdentifier))
        let receivedBlobID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobIdentifier))
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testBlobID, receivedThumbnailID)
        XCTAssertEqual(testBlobID, receivedBlobID)
        XCTAssertEqual(blobProgress, nil)
        // We cannot test for error, since the sending of the message fails and an error is set
    }
    
    @MainActor
    func testOutGoingDataNoActionNeeded() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileData = databasePreparer.createFileData(data: testBlobData)
        let thumbnailData = databasePreparer.createImageData(data: testThumbnailData, height: 10, width: 10)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: testBlobID,
                blobThumbnailID: testThumbnailID,
                data: fileData,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }
        
        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData),
            {
                XCTFail("This should not be called since, we do not have to upload the data of the file message.")
            }
        )
        
        // Act
        let blobManager = BlobManager(
            entityManager: entityManager,
            sessionManager: URLSessionManager(with: TestSessionProvider()),
            serverConnector: ServerConnectorMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString),
            userSettings: UserSettingsMock()
        )
        
        await blobManager.syncBlobs(for: fileMessageEntity.objectID)
                
        // Assert
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    func testOutGoingDataNoteGroup() async throws {
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let taskManagerMock = TaskManagerMock()
        let userSettingsMock = UserSettingsMock()

        let expectedGroupIdentity = GroupIdentity(
            id: MockData.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )

        let groupManager = GroupManager(
            myIdentityStoreMock,
            contactStoreMock,
            taskManagerMock,
            userSettingsMock,
            entityManager,
            GroupPhotoSenderMock()
        )
        
        let grp = createOrUpdateDBWait(
            groupManager: groupManager,
            groupIdentity: expectedGroupIdentity,
            members: []
        )
        
        XCTAssertNotNil(grp)
        
        let conversation = entityManager.entityFetcher.conversation(
            for: grp!.groupID,
            creator: grp!.groupIdentity.creator.string
        )
        
        XCTAssertNotNil(conversation)

        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileData = databasePreparer.createFileData(data: testBlobData)
        let thumbnailData = databasePreparer.createImageData(data: testThumbnailData, height: 10, width: 10)

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation!,
                encryptionKey: encryptionKey,
                blobID: testBlobID,
                blobThumbnailID: testThumbnailID,
                data: fileData,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }

        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData),
            {
                XCTFail("This should not be called since, we do not have to upload the data of the file message.")
            }
        )

        // Act
        let blobManager = BlobManager(
            entityManager: entityManager,
            groupManager: groupManager,
            sessionManager: URLSessionManager(with: TestSessionProvider()),
            serverConnector: ServerConnectorMock(connectionState: .loggedIn),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString),
            userSettings: UserSettingsMock()
        )

        await blobManager.syncBlobs(for: fileMessageEntity.objectID)

        // Assert
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError

        XCTAssertEqual(fileMessageEntity.blobIdentifier, ThreemaProtocol.nonUploadedBlobID)
        XCTAssertEqual(fileMessageEntity.blobThumbnailIdentifier, ThreemaProtocol.nonUploadedBlobID)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testOutGoingNoDataThrows() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                blobThumbnailID: nil,
                data: nil,
                thumbnail: nil,
                isOwn: true
            )
        }
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(
            try await blobManager.syncBlobsThrows(for: fileMessageEntity.objectID)
        ) { error in
            XCTAssertEqual(error as! BlobManagerError, BlobManagerError.noData)
        }
    }
    
    // MARK: - AutoSync Tests

    @MainActor
    func testAutoSyncImage() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                mimeType: "image/jpeg",
                type: NSNumber(integerLiteral: 1),
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let expectationDoneThumbnail = expectation(description: "Basic Incoming Blob Thumbnail Done")
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                expectationDoneData.fulfill()
            }
        )
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData], timeout: 50)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testAutoSyncGIF() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                mimeType: "image/gif",
                type: NSNumber(integerLiteral: 1),
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let expectationDoneThumbnail = expectation(description: "Basic Incoming Blob Thumbnail Done")
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                expectationDoneData.fulfill()
            }
        )
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData], timeout: 50)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testAutoSyncSticker() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                mimeType: "image/png",
                type: NSNumber(integerLiteral: 2),
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let expectationDoneThumbnail = expectation(description: "Basic Incoming Blob Thumbnail Done")
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                expectationDoneData.fulfill()
            }
        )
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData], timeout: 50)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testAutoSyncVoice() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                mimeType: "audio/aac",
                type: NSNumber(integerLiteral: 1),
                isOwn: false
            )
        }
        
        let expectationThumbnail = expectation(description: "Basic Incoming Thumbnail Sync")
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                expectationThumbnail.fulfill()
            }
        )
        
        let expectationDoneThumbnail = expectation(description: "Basic Incoming Blob Thumbnail Done")
        let doneURLThumbnail = try await doneURL(with: baseURLString, and: thumbnailID)
        let doneResponseThumbnail = HTTPURLResponse(
            url: doneURLThumbnail,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        URLProtocolMock.mockResponses[doneURLThumbnail] = (
            (nil, encryptedBlobData, doneResponseThumbnail),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData),
            {
                expectationDoneData.fulfill()
            }
        )
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        wait(for: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData], timeout: 50)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testAutoSyncVideo() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                mimeType: "video/mp4",
                type: NSNumber(integerLiteral: 1),
                isOwn: false
            )
        }
        
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, dataResponse),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // Assert
        let actualBlobData = fileMessageEntity.blobData
        
        XCTAssertEqual(actualBlobData, nil)
    }
    
    @MainActor
    func testAutoSyncFile() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        let thumbnailID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                isOwn: false
            )
        }
        
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        let response = HTTPURLResponse(url: thumbnailURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, encryptedThumbnailData, response),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, dataResponse),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // Assert
        let actualBlobData = fileMessageEntity.blobData
        
        XCTAssertEqual(actualBlobData, nil)
    }
    
    // MARK: - Helper
    
    private func blobURL(with baseURLString: String, and blobID: Data, direction: Direction) async throws -> URL {
        let blobURL = BlobURL(
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString)
        )
        return try await withCheckedThrowingContinuation { continuation in
            // If we have an ID, we are downloading
            if direction == .incoming {
                blobURL.download(blobID: blobID, origin: .local) { url, _ in
                    guard let url else {
                        continuation.resume(throwing: BlobManagerTestsError.urlIsNil)
                        return
                    }
                    
                    continuation.resume(returning: url)
                }
            }
            else {
                blobURL.upload(origin: .local) { url, _, _ in
                    
                    guard let url else {
                        continuation.resume(throwing: BlobManagerTestsError.urlIsNil)
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
        }
    }
    
    private func doneURL(with baseURLString: String, and blobID: Data) async throws -> URL {
        let blobURL = BlobURL(
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString)
        )
        guard let url = try await blobURL.done(blobID: blobID, origin: .local) else {
            throw BlobManagerTestsError.urlIsNil
        }
        return url
    }
    
    private func convertHexToAsciiData(data: Data?) throws -> Data? {
        guard let data else {
            throw BlobManagerTestsError.noData
        }

        return data.hexString.data(using: .ascii)
    }
    
    /// Create or update group in DB and wait until finished.
    @discardableResult private func createOrUpdateDBWait(
        groupManager: GroupManagerProtocol,
        groupIdentity: GroupIdentity,
        members: Set<String>
    ) -> Group? {
        var group: Group?

        let expec = expectation(description: "Group create or update")

        groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: members,
            systemMessageDate: Date(),
            sourceCaller: .local
        )
        .done { grp in
            group = grp
            expec.fulfill()
        }
        .catch { _ in
            expec.fulfill()
        }

        wait(for: [expec], timeout: 30)

        return group
    }
}
