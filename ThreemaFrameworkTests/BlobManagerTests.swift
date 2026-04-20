import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class BlobManagerTests: XCTestCase {
    
    enum BlobManagerTestsError: Error {
        case urlIsNil
        case noData
    }

    enum Direction {
        case incoming, outgoing
    }

    private let testBundle = Bundle(for: BlobManagerTests.self)
    private var context: NSManagedObjectContext!
    private var databasePreparer: TestDatabasePreparer!
    private var conversation: ConversationEntity!
    private var groupConversation: ConversationEntity!
    private var entityManager: EntityManager!
    private var blobManager: BlobManager!
    private let myIdentityStoreMock = MyIdentityStoreMock()
    
    private let baseURLString = "https://example.com"
    private let encryptionKey = BytesUtility.generateBlobEncryptionKey()
    
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
    private let testBlobData = Data("This is test blob data.".utf8)
    private lazy var encryptedBlobData: Data = NaClCrypto.shared().symmetricEncryptData(
        testBlobData,
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
            
            groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
        }
        
        entityManager = testDatabase.entityManager
        
        blobManager = BlobManager(
            entityManager: entityManager,
            groupManager: GroupManagerMock(),
            sessionManager: URLSessionManager(with: TestSessionProvider()),
            serverConnector: ServerConnectorMock(connectionState: .loggedIn),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString),
            userSettings: UserSettingsMock()
        )
    }

    // MARK: - Incoming Tests
    
    @MainActor
    func testIncomingDataNoThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedBlobData, dataResponse, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDone = expectation(description: "Basic Incoming Blob Sync Done")
        let doneURL = try await doneURL(with: baseURLString, and: blobID)
        let doneResponse = HTTPURLResponse(url: doneURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURL] = (
            (nil, encryptedBlobData, doneResponse, nil),
            {
                expectationDone.fulfill()
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(of: [expectationData, expectationDone], timeout: 50)
        
        // Assert
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .downloaded)
        XCTAssertEqual(actualBlobData, testBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingDataWithThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(
            of: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData],
            timeout: 50
        )
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let thumbnail = try XCTUnwrap(fileMessageEntity.thumbnail)
        let loadedThumbnailImage = try XCTUnwrap(UIImage(data: testThumbnailData))
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .downloaded)
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(Int16(loadedThumbnailImage.size.width), thumbnail.width)
        XCTAssertEqual(Int16(loadedThumbnailImage.size.height), thumbnail.height)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    // TODO: (IOS-3875) Timeout
    @MainActor
    func testIncomingDataWithThumbnailNoDone() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                XCTFail("Done must not be called")
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                XCTFail("Done must no be called")
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(of: [expectationThumbnail, expectationData], timeout: 60)
        
        // Assert
        let actualThumbnailData = try XCTUnwrap(fileMessageEntity.blobThumbnail)
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .downloaded)
        XCTAssertEqual(testThumbnailData, actualThumbnailData)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingDataRetryNoThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateBlobID()
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                isOwn: false
            )
        }
        
        entityManager.performAndWaitSave {
            fileMessageEntity.blobError = true
        }
        
        let expectationData = expectation(description: "Basic Incoming Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let response = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDone = expectation(description: "Basic Incoming Sync Done")
        let doneURL = try await doneURL(with: baseURLString, and: blobID)
        let doneResponse = HTTPURLResponse(url: doneURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURL] = (
            (nil, encryptedBlobData, doneResponse, nil),
            {
                expectationDone.fulfill()
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(of: [expectationData, expectationDone], timeout: 50)
        
        // Assert
        let actualBlobData = try XCTUnwrap(fileMessageEntity.blobData)
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .downloaded)
        XCTAssertEqual(testBlobData, actualBlobData)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertEqual(blobError, false)
    }
    
    @MainActor
    func testIncomingNoActionNeeded() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: blobID,
                blobThumbnailID: thumbnailID,
                isOwn: false
            )
        }
        
        entityManager.performAndWaitSave {
            fileMessageEntity.blobThumbnail = self.testThumbnailData
            fileMessageEntity.blobData = self.testBlobData
        }
        
        let thumbnailURL = try await blobURL(with: baseURLString, and: thumbnailID, direction: .incoming)
        
        URLProtocolMock.mockResponses[thumbnailURL] = (
            (nil, nil, nil, nil),
            {
                XCTFail("This should not be called since, we already have all the data of the file message.")
            }
        )
        
        let blobURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[blobURL] = (
            (nil, nil, nil, nil),
            {
                XCTFail("This should not be called since, we already have all the data of the file message.")
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // Assert
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .downloaded)
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
        let fileDataEntity = databasePreparer.createFileDataEntity(data: testBlobData)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                data: fileDataEntity,
                thumbnail: nil,
                isOwn: true
            )
        }
        
        let expectation = expectation(description: "Basic Outgoing Sync")
        let url = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[url] = (
            (nil, testBlobID, response, nil),
            {
                expectation.fulfill()
            }
        )
        
        // Act
        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(of: [expectation], timeout: 50)
        
        // Assert
        let receivedBlobID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobIdentifier))
        
        XCTAssertEqual(actualSyncResult, .uploaded)
        XCTAssertEqual(testBlobID, receivedBlobID)
    }
    
    @MainActor
    func testOutGoingDataWithThumbnail() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileDataEntity = databasePreparer.createFileDataEntity(data: testBlobData)
        let thumbnailData = databasePreparer.createImageDataEntity(data: testThumbnailData, height: 10, width: 10)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: nil,
                blobThumbnailID: nil,
                data: fileDataEntity,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }
        
        let expectationData = expectation(description: "Basic Outgoing Sync")
        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Since the upload urls do not differentiate we wait for two calls of the closure before fulfilling and we
        // check below for testBlobID again.
        var counter = 0
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData, nil),
            {
                counter += 1
                if counter == 2 {
                    expectationData.fulfill()
                }
            }
        )
        
        // Act
        let actualSyncResult = try await blobManager.syncBlobsThrows(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(of: [expectationData], timeout: 50)
        
        // Assert
        let receivedThumbnailID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobThumbnailIdentifier))
        let receivedBlobID = try XCTUnwrap(convertHexToAsciiData(data: fileMessageEntity.blobIdentifier))
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError
        
        XCTAssertEqual(actualSyncResult, .uploaded)
        XCTAssertEqual(testBlobID, receivedThumbnailID)
        XCTAssertEqual(testBlobID, receivedBlobID)
        XCTAssertEqual(blobProgress, nil)
        XCTAssertFalse(blobError)
    }
    
    @MainActor
    func testOutGoingDataNoInternetConnection() async throws {
        
        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileDataEntity = databasePreparer.createFileDataEntity(data: testBlobData)
        let thumbnailData = databasePreparer.createImageDataEntity(data: testThumbnailData, height: 10, width: 10)
        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                blobID: testBlobID,
                blobThumbnailID: testThumbnailID,
                data: fileDataEntity,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }
        
        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData, nil),
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
        
        await XCTAssertThrowsAsyncError(
            try await blobManager.syncBlobsThrows(for: fileMessageEntity.objectID)
        ) { error in
            XCTAssertEqual(error as! BlobManagerError, BlobManagerError.notConnected)
        }
    }
    
    func testOutGoingDataNoteGroup() async throws {
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingsMock = UserSettingsMock()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )

        let (group, conversationEntity) = try databasePreparer.save {
            let (_, groupEntity, conversationEntity) = try databasePreparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )
            return (
                Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: userSettingsMock,
                    pushSettingManager: PushSettingManagerMock(),
                    groupEntity: groupEntity,
                    conversation: conversationEntity,
                    lastSyncRequest: nil
                ),
                conversationEntity
            )
        }

        // Arrange
        var fileMessageEntity: FileMessageEntity!
        let fileDataEntity = databasePreparer.createFileDataEntity(data: testBlobData)
        let thumbnailData = databasePreparer.createImageDataEntity(data: testThumbnailData, height: 10, width: 10)

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(
                conversation: conversationEntity,
                encryptionKey: encryptionKey,
                blobID: testBlobID,
                blobThumbnailID: testThumbnailID,
                data: fileDataEntity,
                thumbnail: thumbnailData,
                isOwn: true
            )
        }

        let dataURL = try await blobURL(with: baseURLString, and: testBlobID, direction: .outgoing)
        let responseData = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, testBlobID, responseData, nil),
            {
                XCTFail("This should not be called since, we do not have to upload the data of the file message.")
            }
        )

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(group)

        // Act
        let blobManager = BlobManager(
            entityManager: entityManager,
            groupManager: groupManagerMock,
            sessionManager: URLSessionManager(with: TestSessionProvider()),
            serverConnector: ServerConnectorMock(connectionState: .loggedIn),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: baseURLString),
            userSettings: UserSettingsMock()
        )

        let actualSyncResult = await blobManager.syncBlobs(for: fileMessageEntity.objectID)

        // Assert
        let blobProgress = fileMessageEntity.blobProgress
        let blobError = fileMessageEntity.blobError

        XCTAssertEqual(actualSyncResult, .failed) // Internally it throws `BlobManagerError.noteGroupNeedsNoSync`
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(
            of: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData],
            timeout: 50
        )
        
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(
            of: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData],
            timeout: 50
        )
        
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(
            of: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData],
            timeout: 50
        )
        
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
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
            (nil, encryptedBlobData, doneResponseThumbnail, nil),
            {
                expectationDoneThumbnail.fulfill()
            }
        )
        
        let expectationData = expectation(description: "Basic Incoming Blob Sync")
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        
        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, response, nil),
            {
                expectationData.fulfill()
            }
        )
        
        let expectationDoneData = expectation(description: "Basic Incoming Blob Data Done")
        let doneURLData = try await doneURL(with: baseURLString, and: blobID)
        let doneResponseData = HTTPURLResponse(url: doneURLData, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.mockResponses[doneURLData] = (
            (nil, encryptedBlobData, doneResponseData, nil),
            {
                expectationDoneData.fulfill()
            }
        )
        
        // Act
        await blobManager.autoSyncBlobs(for: fileMessageEntity.objectID)
        
        // TODO: (IOS-3875) Timeout
        await fulfillment(
            of: [expectationThumbnail, expectationDoneThumbnail, expectationData, expectationDoneData],
            timeout: 50
        )
        
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, dataResponse, nil),
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
        let blobID = BytesUtility.generateBlobID()
        let thumbnailID = BytesUtility.generateBlobID()
        
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
            (nil, encryptedThumbnailData, response, nil),
            {
                XCTFail("This must no be called since we don't want an auto sync to start.")
            }
        )
        
        let dataURL = try await blobURL(with: baseURLString, and: blobID, direction: .incoming)
        let dataResponse = HTTPURLResponse(url: dataURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        URLProtocolMock.mockResponses[dataURL] = (
            (nil, encryptedBlobData, dataResponse, nil),
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
                blobURL.upload(origin: .local, setPersistParam: false) { url, _, _ in
                    
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
}
