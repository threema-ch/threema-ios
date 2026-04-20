import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class EntityCreatorExtensionTests: XCTestCase {
    private var conversation: ConversationEntity!
    private var entityCreator: EntityCreator!
    private var entityManager: EntityManager!

    override func setUpWithError() throws {
        let testDatabase = TestDatabase()

        let databasePreparer = testDatabase.backgroundPreparer
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }

        entityManager = testDatabase.backgroundEntityManager
    }

    // MARK: - Abstract messages

    func testCreateTextMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedText = "Hello world!"

        let boxTextMessage = BoxTextMessage()

        // Set basics
        boxTextMessage.messageID = expectedMessageID
        boxTextMessage.date = expectedRemoteSentDate
        boxTextMessage.flags = expectedFlags
        boxTextMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        boxTextMessage.text = expectedText

        // Run
        let textMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.textMessageEntity(
                from: boxTextMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(textMessageEntity)
            XCTAssertEqual(textMessageEntity.id, expectedMessageID)
            XCTAssertEqual(textMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(textMessageEntity.flags, expectedFlags)
            XCTAssertEqual(textMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(textMessageEntity.text, expectedText)
        }
    }

    func testCreateTextMessageEntityFromAbstractMessageWithQuote() async throws {
        let expectedText = "Hello world!"
        let expectedQuotedMessageID = BytesUtility.generateMessageID()

        let boxTextMessage = BoxTextMessage()
        boxTextMessage.text = expectedText
        boxTextMessage.quotedMessageID = expectedQuotedMessageID
        boxTextMessage.flags = NSNumber(integerLiteral: 12_345_678)

        let textMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.textMessageEntity(
                from: boxTextMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(textMessageEntity)
            XCTAssertEqual(textMessageEntity.text, expectedText)
            XCTAssertEqual(textMessageEntity.quotedMessageID, expectedQuotedMessageID)
        }
    }

    func testCreateTextMessageEntityFromAbstractGroupMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedText = "Hello world!"

        let groupTextMessage = GroupTextMessage()

        // Set basics
        groupTextMessage.messageID = expectedMessageID
        groupTextMessage.date = expectedRemoteSentDate
        groupTextMessage.flags = expectedFlags
        groupTextMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        groupTextMessage.text = expectedText

        // Run

        let textMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.textMessageEntity(
                from: groupTextMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(textMessageEntity)
            XCTAssertEqual(textMessageEntity.id, expectedMessageID)
            XCTAssertEqual(textMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(textMessageEntity.flags, expectedFlags)
            XCTAssertEqual(textMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(textMessageEntity.text, expectedText)
        }
    }

    func testCreateImageMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedImageSize: UInt32 = 500_000
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedImageNonce = BytesUtility.generateMessageNonce()

        let boxImageMessage = BoxImageMessage()

        // Set basics
        boxImageMessage.messageID = expectedMessageID
        boxImageMessage.date = expectedRemoteSentDate
        boxImageMessage.flags = expectedFlags
        boxImageMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        boxImageMessage.size = expectedImageSize
        boxImageMessage.blobID = expectedBlobID
        boxImageMessage.imageNonce = expectedImageNonce

        // Run

        let imageMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.imageMessageEntity(
                from: boxImageMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(imageMessageEntity)
            XCTAssertEqual(imageMessageEntity.id, expectedMessageID)
            XCTAssertEqual(imageMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(imageMessageEntity.flags, expectedFlags)
            XCTAssertEqual(imageMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(imageMessageEntity.imageSize?.uint32Value, expectedImageSize)
            XCTAssertEqual(imageMessageEntity.imageBlobID, expectedBlobID)
            XCTAssertNil(imageMessageEntity.encryptionKey)
            XCTAssertEqual(imageMessageEntity.imageNonce, expectedImageNonce)
        }
    }

    func testCreateImageMessageEntityFromAbstractGroupMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedImageSize: UInt32 = 500_000
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        let groupImageMessage = GroupImageMessage()

        // Set basics
        groupImageMessage.messageID = expectedMessageID
        groupImageMessage.date = expectedRemoteSentDate
        groupImageMessage.flags = expectedFlags
        groupImageMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        groupImageMessage.size = expectedImageSize
        groupImageMessage.blobID = expectedBlobID
        groupImageMessage.encryptionKey = expectedEncryptionKey

        // Run

        let imageMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.imageMessageEntity(
                from: groupImageMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(imageMessageEntity)
            XCTAssertEqual(imageMessageEntity.id, expectedMessageID)
            XCTAssertEqual(imageMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(imageMessageEntity.flags, expectedFlags)
            XCTAssertEqual(imageMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(imageMessageEntity.imageSize?.uint32Value, expectedImageSize)
            XCTAssertEqual(imageMessageEntity.imageBlobID, expectedBlobID)
            XCTAssertNil(imageMessageEntity.imageNonce)
            // TODO: (IOS-5235)
            // XCTAssertEqual(imageMessageEntity.encryptionKey, expectedEncryptionKey)
        }
    }

    func testCreateVideoMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedDuration: UInt16 = 200
        let expectedSize: UInt32 = 123_456
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        let boxVideoMessage = BoxVideoMessage()

        // Set basics
        boxVideoMessage.messageID = expectedMessageID
        boxVideoMessage.date = expectedRemoteSentDate
        boxVideoMessage.flags = expectedFlags
        boxVideoMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        boxVideoMessage.duration = expectedDuration
        boxVideoMessage.videoSize = expectedSize
        boxVideoMessage.videoBlobID = expectedBlobID
        boxVideoMessage.encryptionKey = expectedEncryptionKey

        // Run

        let videoMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.videoMessageEntity(
                from: boxVideoMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(videoMessageEntity)
            XCTAssertEqual(videoMessageEntity.id, expectedMessageID)
            XCTAssertEqual(videoMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(videoMessageEntity.flags, expectedFlags)
            XCTAssertEqual(videoMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(videoMessageEntity.duration.uint16Value, expectedDuration)
            XCTAssertEqual(videoMessageEntity.videoSize?.uint32Value, expectedSize)
            XCTAssertEqual(videoMessageEntity.videoBlobID, expectedBlobID)
            XCTAssertEqual(videoMessageEntity.encryptionKey, expectedEncryptionKey)
        }
    }

    func testCreateVideoMessageEntityFromAbstractGroupMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedDuration: UInt16 = 200
        let expectedSize: UInt32 = 123_456
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        let groupVideoMessage = GroupVideoMessage()

        // Set basics
        groupVideoMessage.messageID = expectedMessageID
        groupVideoMessage.date = expectedRemoteSentDate
        groupVideoMessage.flags = expectedFlags
        groupVideoMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        groupVideoMessage.duration = expectedDuration
        groupVideoMessage.videoSize = expectedSize
        groupVideoMessage.videoBlobID = expectedBlobID
        groupVideoMessage.encryptionKey = expectedEncryptionKey

        // Run

        let videoMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.videoMessageEntity(
                from: groupVideoMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(videoMessageEntity)
            XCTAssertEqual(videoMessageEntity.id, expectedMessageID)
            XCTAssertEqual(videoMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(videoMessageEntity.flags, expectedFlags)
            XCTAssertEqual(videoMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(videoMessageEntity.duration.uint16Value, expectedDuration)
            XCTAssertEqual(videoMessageEntity.videoSize?.uint32Value, expectedSize)
            XCTAssertEqual(videoMessageEntity.videoBlobID, expectedBlobID)
            XCTAssertEqual(videoMessageEntity.encryptionKey, expectedEncryptionKey)
        }
    }

    func testCreateAudioMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedDuration: UInt16 = 300
        let expectedSize: UInt32 = 12345
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        let boxAudioMessage = BoxAudioMessage()

        // Set basics
        boxAudioMessage.messageID = expectedMessageID
        boxAudioMessage.date = expectedRemoteSentDate
        boxAudioMessage.flags = expectedFlags
        boxAudioMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        boxAudioMessage.duration = expectedDuration
        boxAudioMessage.audioSize = expectedSize
        boxAudioMessage.audioBlobID = expectedBlobID
        boxAudioMessage.encryptionKey = expectedEncryptionKey

        // Run

        let audioMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.audioMessageEntity(
                from: boxAudioMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(audioMessageEntity)
            XCTAssertEqual(audioMessageEntity.id, expectedMessageID)
            XCTAssertEqual(audioMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(audioMessageEntity.flags, expectedFlags)
            XCTAssertEqual(audioMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(audioMessageEntity.duration.uint16Value, expectedDuration)
            XCTAssertEqual(audioMessageEntity.audioSize?.uint32Value, expectedSize)
            XCTAssertEqual(audioMessageEntity.audioBlobID, expectedBlobID)
            XCTAssertEqual(audioMessageEntity.encryptionKey, expectedEncryptionKey)
        }
    }

    func testCreateAudioMessageEntityFromAbstractGroupMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedDuration: UInt16 = 300
        let expectedSize: UInt32 = 12345
        let expectedBlobID = BytesUtility.generateBlobID()
        let expectedEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        let groupAudioMessage = GroupAudioMessage()

        // Set basics
        groupAudioMessage.messageID = expectedMessageID
        groupAudioMessage.date = expectedRemoteSentDate
        groupAudioMessage.flags = expectedFlags
        groupAudioMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        groupAudioMessage.duration = expectedDuration
        groupAudioMessage.audioSize = expectedSize
        groupAudioMessage.audioBlobID = expectedBlobID
        groupAudioMessage.encryptionKey = expectedEncryptionKey

        // Run

        let audioMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.audioMessageEntity(
                from: groupAudioMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(audioMessageEntity)
            XCTAssertEqual(audioMessageEntity.id, expectedMessageID)
            XCTAssertEqual(audioMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(audioMessageEntity.flags, expectedFlags)
            XCTAssertEqual(audioMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(audioMessageEntity.duration.uint16Value, expectedDuration)
            XCTAssertEqual(audioMessageEntity.audioSize?.uint32Value, expectedSize)
            XCTAssertEqual(audioMessageEntity.audioBlobID, expectedBlobID)
            XCTAssertEqual(audioMessageEntity.encryptionKey, expectedEncryptionKey)
        }
    }

    func testCreateLocationMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedLatitude = 123.45
        let expectedLongitude = 678.90
        let expectedAccuracy = 100.023
        let expectedPOIName = "POI"
        let expectedPOIAddress = "Street 1, 1234 Threema"

        let boxLocationMessage = BoxLocationMessage()

        // Set basics
        boxLocationMessage.messageID = expectedMessageID
        boxLocationMessage.date = expectedRemoteSentDate
        boxLocationMessage.flags = expectedFlags
        boxLocationMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        boxLocationMessage.latitude = expectedLatitude
        boxLocationMessage.longitude = expectedLongitude
        boxLocationMessage.accuracy = expectedAccuracy
        boxLocationMessage.poiName = expectedPOIName
        boxLocationMessage.poiAddress = expectedPOIAddress

        // Run

        let locationMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.locationMessageEntity(
                from: boxLocationMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(locationMessageEntity)
            XCTAssertEqual(locationMessageEntity.id, expectedMessageID)
            XCTAssertEqual(locationMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(locationMessageEntity.flags, expectedFlags)
            XCTAssertEqual(locationMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(locationMessageEntity.latitude.doubleValue, expectedLatitude)
            XCTAssertEqual(locationMessageEntity.longitude.doubleValue, expectedLongitude)
            XCTAssertEqual(locationMessageEntity.accuracy?.doubleValue, expectedAccuracy)
            XCTAssertEqual(locationMessageEntity.poiName, expectedPOIName)
            XCTAssertEqual(locationMessageEntity.poiAddress, expectedPOIAddress)
        }
    }

    func testCreateLocationMessageEntityFromAbstractGroupMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        // Custom
        let expectedLatitude = 123.45
        let expectedLongitude = 678.90
        let expectedAccuracy = 100.023
        let expectedPOIName = "POI"
        let expectedPOIAddress = "Street 1, 1234 Threema"

        let groupLocationMessage = GroupLocationMessage()

        // Set basics
        groupLocationMessage.messageID = expectedMessageID
        groupLocationMessage.date = expectedRemoteSentDate
        groupLocationMessage.flags = expectedFlags
        groupLocationMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Set custom
        groupLocationMessage.latitude = expectedLatitude
        groupLocationMessage.longitude = expectedLongitude
        groupLocationMessage.accuracy = expectedAccuracy
        groupLocationMessage.poiName = expectedPOIName
        groupLocationMessage.poiAddress = expectedPOIAddress

        // Run

        let locationMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.locationMessageEntity(
                from: groupLocationMessage, in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(locationMessageEntity)
            XCTAssertEqual(locationMessageEntity.id, expectedMessageID)
            XCTAssertEqual(locationMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(locationMessageEntity.flags, expectedFlags)
            XCTAssertEqual(locationMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertEqual(locationMessageEntity.latitude.doubleValue, expectedLatitude)
            XCTAssertEqual(locationMessageEntity.longitude.doubleValue, expectedLongitude)
            XCTAssertEqual(locationMessageEntity.accuracy?.doubleValue, expectedAccuracy)
            XCTAssertEqual(locationMessageEntity.poiName, expectedPOIName)
            XCTAssertEqual(locationMessageEntity.poiAddress, expectedPOIAddress)
        }
    }

    func testCreateBallotMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        let boxBallotMessage = BoxBallotCreateMessage()

        // Set basics
        boxBallotMessage.messageID = expectedMessageID
        boxBallotMessage.date = expectedRemoteSentDate
        boxBallotMessage.flags = expectedFlags
        boxBallotMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Run

        let ballotMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.ballotMessageEntity(
                from: boxBallotMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.validateBasicsOfNewMessageEntityFromAbstractMessage(ballotMessageEntity)
            XCTAssertEqual(ballotMessageEntity.id, expectedMessageID)
            XCTAssertEqual(ballotMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(ballotMessageEntity.flags, expectedFlags)
            XCTAssertEqual(ballotMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertNil(ballotMessageEntity.ballot)
        }
    }

    func testCreateFileMessageEntityFromAbstractMessage() async throws {
        // Basics
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedRemoteSentDate = Date.now - 1
        let expectedFlags = NSNumber(integerLiteral: 12_345_678)
        let expectedForwardSecurityMode = ForwardSecurityMode.none

        let boxFileMessage = BoxFileMessage()

        // Set basics
        boxFileMessage.messageID = expectedMessageID
        boxFileMessage.date = expectedRemoteSentDate
        boxFileMessage.flags = expectedFlags
        boxFileMessage.forwardSecurityMode = expectedForwardSecurityMode

        // Run

        let fileMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.fileMessageEntity(
                from: boxFileMessage,
                in: self.conversation
            )
        }

        // Validate

        await entityManager.perform {
            self.self.validateBasicsOfNewMessageEntityFromAbstractMessage(fileMessageEntity)
            XCTAssertEqual(fileMessageEntity.id, expectedMessageID)
            XCTAssertEqual(fileMessageEntity.remoteSentDate, expectedRemoteSentDate)
            XCTAssertEqual(fileMessageEntity.flags, expectedFlags)
            XCTAssertEqual(fileMessageEntity.forwardSecurityMode.uintValue, expectedForwardSecurityMode.rawValue)
            XCTAssertNil(fileMessageEntity.blobID)
            XCTAssertNil(fileMessageEntity.blobThumbnailID)
        }
    }

    // MARK: Abstract message validation

    func validateBasicsOfNewMessageEntityFromAbstractMessage(_ messageEntity: BaseMessageEntity) {
        XCTAssertFalse(messageEntity.isOwnMessage)
        XCTAssertEqual(messageEntity.sent, NSNumber(booleanLiteral: false))
        XCTAssertEqual(messageEntity.delivered, NSNumber(booleanLiteral: false))
        XCTAssertEqual(messageEntity.read, NSNumber(booleanLiteral: false))
    }
}
