//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class AbstractMessageEncodeDecodeTests: XCTestCase {
    
    private let expectedFromIdentity = "FROMID01"
    private let expectedToIdentity = "TOID0123"
    private let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: 8)!
    private let expectedPushFromName = "pushFromName"
    private let expectedDate = Date()
    private let expectedDeliveryDate: Date? = Date()
    private let expectedDelivered = true
    private let expectedUserAck = false
    private let expectedSendUserAck = true
    private let expectedNonce: Data = BytesUtility.generateRandomBytes(length: 24)!
    private let expectedFlags = 1
    private let expectedReceivedAfterInitialQueueSend = false
    
    private func abstractMessage<T: AbstractMessage>(
        _ fromIdentity: String,
        _ toIdentity: String,
        _ messageID: Data,
        _ pushFromName: String,
        _ date: Date,
        _ deliveryDate: Date?,
        _ delivered: Bool,
        _ userAck: Bool,
        _ sendUserAck: Bool,
        _ nonce: Data,
        _ flags: Int,
        _ receivedAfterInitialQueueSend: Bool
    ) -> T {
        let msg = T()
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toIdentity
        msg.messageID = messageID
        msg.pushFromName = pushFromName
        msg.date = date
        msg.deliveryDate = deliveryDate
        msg.delivered = NSNumber(booleanLiteral: delivered)
        msg.userAck = NSNumber(booleanLiteral: userAck)
        msg.sendUserAck = NSNumber(booleanLiteral: sendUserAck)
        msg.nonce = nonce
        msg.flags = NSNumber(integerLiteral: flags)
        msg.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend
        return msg
    }
    
    private func encodeDecode<T: AbstractMessage>(message: T) throws -> T? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(message, forKey: "message")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        return try unarchiver.decodeTopLevelObject(of: T.self, forKey: "message")
    }
    
    func testAllAbstractMessagesWithoutOwnProperties() throws {
        func testAbstractMessage<T: AbstractMessage>() throws -> T {
            let msg: T = abstractMessage(
                expectedFromIdentity,
                expectedToIdentity,
                expectedMessageID,
                expectedPushFromName,
                expectedDate,
                expectedDeliveryDate,
                expectedDelivered,
                expectedUserAck,
                expectedSendUserAck,
                expectedNonce,
                expectedFlags,
                expectedReceivedAfterInitialQueueSend
            )

            let result = try XCTUnwrap(encodeDecode(message: msg))

            XCTAssertEqual(expectedFromIdentity, result.fromIdentity)
            XCTAssertEqual(expectedToIdentity, result.toIdentity)
            XCTAssertEqual(expectedMessageID, result.messageID)
            XCTAssertEqual(expectedPushFromName, result.pushFromName)
            XCTAssertEqual(expectedDate, result.date)
            XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result.delivered)
            XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result.userAck)
            XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result.sendUserAck)
            XCTAssertTrue(expectedNonce.elementsEqual(result.nonce))
            XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), result.flags)
            XCTAssertFalse(result.receivedAfterInitialQueueSend)
            XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)

            return result
        }

        let _: BoxVoIPCallAnswerMessage = try testAbstractMessage()
        let _: BoxVoIPCallHangupMessage = try testAbstractMessage()
        let _: BoxVoIPCallIceCandidatesMessage = try testAbstractMessage()
        let _: BoxVoIPCallOfferMessage = try testAbstractMessage()
        let _: BoxVoIPCallRingingMessage = try testAbstractMessage()
        let _: ContactDeletePhotoMessage = try testAbstractMessage()
        let _: ContactRequestPhotoMessage = try testAbstractMessage()
        let _: GroupDeletePhotoMessage = try testAbstractMessage()
        let _: GroupLeaveMessage = try testAbstractMessage()
        let _: GroupRequestSyncMessage = try testAbstractMessage()
        let _: TypingIndicatorMessage = try testAbstractMessage()
        let _: UnknownTypeMessage = try testAbstractMessage()
    }

    func testBoxAudioMessage() throws {
        let expectedDuration: UInt16 = 10
        let expectedAudioBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedAudioSize: UInt32 = 100
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: BoxAudioMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.duration = expectedDuration
        msg.audioBlobID = expectedAudioBlobID
        msg.audioSize = expectedAudioSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: BoxAudioMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertEqual(expectedDuration, result?.duration)
        XCTAssertTrue(expectedAudioBlobID.elementsEqual((result?.audioBlobID)!))
        XCTAssertEqual(expectedAudioSize, result?.audioSize)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testBoxBallotCreateMessage() throws {
        let expectedBallotID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedJsonData: Data = BytesUtility.generateRandomBytes(length: 58)!
        
        let msg: BoxBallotCreateMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.ballotID = expectedBallotID
        msg.jsonData = expectedJsonData
        
        let result: BoxBallotCreateMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedBallotID.elementsEqual((result?.ballotID)!))
        XCTAssertTrue(expectedJsonData.elementsEqual((result?.jsonData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testBoxBallotVoteMessage() throws {
        let expectedBallotCreator = "CREATOR1"
        let expectedBallotID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedJsonChoiceData: Data = BytesUtility.generateRandomBytes(length: 5)!
        
        let msg: BoxBallotVoteMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.ballotCreator = expectedBallotCreator
        msg.ballotID = expectedBallotID
        msg.jsonChoiceData = expectedJsonChoiceData
        
        let result: BoxBallotVoteMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)

        XCTAssertEqual(expectedBallotCreator, result?.ballotCreator)
        XCTAssertTrue(expectedBallotID.elementsEqual((result?.ballotID)!))
        XCTAssertTrue(expectedJsonChoiceData.elementsEqual((result?.jsonChoiceData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testBoxFileMessage() throws {
        let jsonData: Data = BytesUtility.generateRandomBytes(length: 6)!
        
        let msg: BoxFileMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.jsonData = jsonData
        
        let result: BoxFileMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)

        XCTAssertTrue(jsonData.elementsEqual((result?.jsonData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testBoxImageMessage() throws {
        let expectedBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedSize: UInt32 = 100
        let expectedImageNonce: Data = BytesUtility.generateRandomBytes(length: 24)!
        
        let msg: BoxImageMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.blobID = expectedBlobID
        msg.size = expectedSize
        msg.imageNonce = expectedImageNonce
        
        let result: BoxImageMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedBlobID.elementsEqual((result?.blobID)!))
        XCTAssertEqual(expectedSize, result?.size)
        XCTAssertTrue(expectedImageNonce.elementsEqual((result?.imageNonce)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testBoxLocationMessage() throws {
        let expectedAccuracy = 0.12
        let expectedLatitude = 123.987
        let expectedLongitude = 98.12344
        let expectedPoiAddress = "Address"
        let expectedPoiName = "Name"
        
        let msg: BoxLocationMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.accuracy = expectedAccuracy
        msg.latitude = expectedLatitude
        msg.longitude = expectedLongitude
        msg.poiAddress = expectedPoiAddress
        msg.poiName = expectedPoiName
        
        let result: BoxLocationMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertEqual(expectedAccuracy, result?.accuracy)
        XCTAssertEqual(expectedLatitude, result?.latitude)
        XCTAssertEqual(expectedLongitude, result?.longitude)
        XCTAssertEqual(expectedPoiAddress, result?.poiAddress)
        XCTAssertEqual(expectedPoiName, result?.poiName)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testBoxTextMessage() throws {
        let expectedText = "Test text"
        let expectedQuotedMessageID: Data = BytesUtility.generateRandomBytes(length: 8)!
        
        let msg: BoxTextMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.text = expectedText
        msg.quotedMessageID = expectedQuotedMessageID
        
        let result: BoxTextMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertEqual(expectedText, result?.text)
        XCTAssertTrue(expectedQuotedMessageID.elementsEqual((result?.quotedMessageID)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNotNil(try XCTUnwrap(result) as QuotedMessageProtocol)
    }
    
    func testBoxVideoMessage() throws {
        let expectedDuration: UInt16 = 10
        let expectedVideoBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedVideoSize: UInt32 = 100
        let expectedThumbnailBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedThumbnailSize: UInt32 = 50
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: BoxVideoMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.duration = expectedDuration
        msg.videoBlobID = expectedVideoBlobID
        msg.videoSize = expectedVideoSize
        msg.thumbnailBlobID = expectedThumbnailBlobID
        msg.thumbnailSize = expectedThumbnailSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: BoxVideoMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertEqual(expectedDuration, result?.duration)
        XCTAssertTrue(expectedVideoBlobID.elementsEqual((result?.videoBlobID)!))
        XCTAssertEqual(expectedVideoSize, result?.videoSize)
        XCTAssertTrue(expectedThumbnailBlobID.elementsEqual((result?.thumbnailBlobID)!))
        XCTAssertEqual(expectedThumbnailSize, result?.thumbnailSize)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testContactSetPhotoMessage() throws {
        let expectedBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedSize: UInt32 = 200
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: ContactSetPhotoMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.blobID = expectedBlobID
        msg.size = expectedSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: ContactSetPhotoMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedBlobID.elementsEqual((result?.blobID)!))
        XCTAssertEqual(expectedSize, result?.size)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testDeliveryReceiptMessage() throws {
        let expectedReceiptType: ReceiptType = .ack
        let expectedReceiptMessageIDs: [Data] = [
            BytesUtility.generateRandomBytes(length: 8)!,
            BytesUtility.generateRandomBytes(length: 8)!,
        ]
        
        let msg: DeliveryReceiptMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.receiptType = expectedReceiptType
        msg.receiptMessageIDs = expectedReceiptMessageIDs
        
        let result: DeliveryReceiptMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertEqual(expectedReceiptType, result?.receiptType)
        XCTAssertEqual(2, result?.receiptMessageIDs.count)
        XCTAssertTrue(expectedReceiptMessageIDs[0].elementsEqual(result?.receiptMessageIDs[0] as! Data))
        XCTAssertTrue(expectedReceiptMessageIDs[1].elementsEqual(result?.receiptMessageIDs[1] as! Data))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testEditGroupMessage() throws {
        let expectedGroupID: Data = MockData.generateGroupID()
        let expectedGroupCreator = "CREATOR1"
        var expectedEditMessage = CspE2e_EditMessage()
        expectedEditMessage.messageID = try MockData.generateMessageID().littleEndian()
        expectedEditMessage.text = "Test 123"

        let msg: EditGroupMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )

        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.decoded = expectedEditMessage

        let result: EditGroupMessage? = try encodeDecode(message: msg)

        XCTAssertNotNil(result)

        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedEditMessage, result?.decoded)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testEditMessage() throws {
        var expectedEditMessage = CspE2e_EditMessage()
        expectedEditMessage.messageID = try MockData.generateMessageID().littleEndian()
        expectedEditMessage.text = "Test 123"

        let msg: EditMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )

        msg.decoded = expectedEditMessage

        let result: EditMessage? = try encodeDecode(message: msg)

        XCTAssertNotNil(result)

        XCTAssertEqual(expectedEditMessage, result?.decoded)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    // TODO: (IOS-3949) Test changed
    func testForwardSecurityEnvelopeMessage() throws {
        let expectedSessionID = BytesUtility.generateRandomBytes(length: DHSessionID.dhSessionIDLength)!

        let msg = try ForwardSecurityEnvelopeMessage(
            data: ForwardSecurityDataMessage(
                sessionID: DHSessionID(value: expectedSessionID),
                type: .twodh,
                counter: 1,
                groupIdentity: nil,
                offeredVersion: .v11,
                appliedVersion: .v11,
                message: BytesUtility.generateRandomBytes(length: 48)!
            )
        )
        msg.fromIdentity = expectedFromIdentity
        msg.toIdentity = expectedToIdentity
        msg.messageID = expectedMessageID
        msg.pushFromName = expectedPushFromName
        msg.date = expectedDate
        msg.deliveryDate = expectedDeliveryDate
        msg.delivered = NSNumber(booleanLiteral: expectedDelivered)
        msg.userAck = NSNumber(booleanLiteral: expectedUserAck)
        msg.sendUserAck = NSNumber(booleanLiteral: expectedSendUserAck)
        msg.nonce = expectedNonce
        msg.flags = NSNumber(integerLiteral: expectedFlags)
        msg.receivedAfterInitialQueueSend = expectedReceivedAfterInitialQueueSend

        let result: ForwardSecurityEnvelopeMessage? = try encodeDecode(message: msg)

        XCTAssertNotNil(result)

        XCTAssertEqual(expectedSessionID, result?.data.sessionID.value)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testGroupAudioMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedDuration: UInt16 = 10
        let expectedAudioBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedAudioSize: UInt32 = 100
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: GroupAudioMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.duration = expectedDuration
        msg.audioBlobID = expectedAudioBlobID
        msg.audioSize = expectedAudioSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: GroupAudioMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedDuration, result?.duration)
        XCTAssertTrue(expectedAudioBlobID.elementsEqual((result?.audioBlobID)!))
        XCTAssertEqual(expectedAudioSize, result?.audioSize)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupBallotCreateMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedBallotID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedJsonData: Data = BytesUtility.generateRandomBytes(length: 58)!
        
        let msg: GroupBallotCreateMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.ballotID = expectedBallotID
        msg.jsonData = expectedJsonData
        
        let result: GroupBallotCreateMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertTrue(expectedBallotID.elementsEqual((result?.ballotID)!))
        XCTAssertTrue(expectedJsonData.elementsEqual((result?.jsonData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupBallotVoteMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedBallotCreator = "CREATOR1"
        let expectedBallotID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedJsonChoiceData: Data = BytesUtility.generateRandomBytes(length: 5)!
        
        let msg: GroupBallotVoteMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.ballotCreator = expectedBallotCreator
        msg.ballotID = expectedBallotID
        msg.jsonChoiceData = expectedJsonChoiceData
        
        let result: GroupBallotVoteMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)

        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedBallotCreator, result?.ballotCreator)
        XCTAssertTrue(expectedBallotID.elementsEqual((result?.ballotID)!))
        XCTAssertTrue(expectedJsonChoiceData.elementsEqual((result?.jsonChoiceData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupCallStartMessage() throws {
        let expectedGroupID: Data = MockData.generateGroupID()
        let expectedGroupCreator = "CREATOR1"
        var expectedGroupCallStartMessage = CspE2e_GroupCallStart()
        expectedGroupCallStartMessage.gck = MockData.generatePublicKey()
        expectedGroupCallStartMessage.protocolVersion = 1
        expectedGroupCallStartMessage.sfuBaseURL = "https://sfu"

        let msg: GroupCallStartMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )

        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.decoded = expectedGroupCallStartMessage

        let result: GroupCallStartMessage? = try encodeDecode(message: msg)

        XCTAssertNotNil(result)

        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedGroupCallStartMessage, result?.decoded)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testGroupCreateMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedGroupMembers: [String] = ["MEMBER01", "MEMBER02"]
        
        let msg: GroupCreateMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.groupMembers = expectedGroupMembers
        
        let result: GroupCreateMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)

        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedGroupMembers, result?.groupMembers as! [String])

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupFileMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedJsonData: Data = BytesUtility.generateRandomBytes(length: 6)!
        
        let msg: GroupFileMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.jsonData = expectedJsonData
        
        let result: GroupFileMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)

        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertTrue(expectedJsonData.elementsEqual((result?.jsonData)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }

    func testGroupImageMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedSize: UInt32 = 100
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 24)!
        
        let msg: GroupImageMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.blobID = expectedBlobID
        msg.size = expectedSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: GroupImageMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertTrue(expectedBlobID.elementsEqual((result?.blobID)!))
        XCTAssertEqual(expectedSize, result?.size)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupRenameMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedName = "New name"
        
        let msg: GroupRenameMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.name = expectedName
        
        let result: GroupRenameMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedName, result?.name)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupLocationMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedAccuracy = 0.12
        let expectedLatitude = 123.987
        let expectedLongitude = 98.12344
        let expectedPoiAddress = "Address"
        let expectedPoiName = "Name"
        
        let msg: GroupLocationMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.accuracy = expectedAccuracy
        msg.latitude = expectedLatitude
        msg.longitude = expectedLongitude
        msg.poiAddress = expectedPoiAddress
        msg.poiName = expectedPoiName
        
        let result: GroupLocationMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedAccuracy, result?.accuracy)
        XCTAssertEqual(expectedLatitude, result?.latitude)
        XCTAssertEqual(expectedLongitude, result?.longitude)
        XCTAssertEqual(expectedPoiAddress, result?.poiAddress)
        XCTAssertEqual(expectedPoiName, result?.poiName)

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupSetPhotoMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedSize: UInt32 = 200
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: GroupSetPhotoMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.blobID = expectedBlobID
        msg.size = expectedSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: GroupSetPhotoMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertTrue(expectedBlobID.elementsEqual((result?.blobID)!))
        XCTAssertEqual(expectedSize, result?.size)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupTextMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedText = "Test group text"
        let expectedQuotedMessageID: Data = BytesUtility.generateRandomBytes(length: 8)!

        let msg: GroupTextMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.text = expectedText
        msg.quotedMessageID = expectedQuotedMessageID
        
        let result: GroupTextMessage? = try encodeDecode(message: msg)

        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedText, result?.text)
        XCTAssertTrue(expectedQuotedMessageID.elementsEqual((result?.quotedMessageID)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNotNil(try XCTUnwrap(result) as QuotedMessageProtocol)
    }
    
    func testGroupVideoMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedDuration: UInt16 = 10
        let expectedVideoBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedVideoSize: UInt32 = 100
        let expectedThumbnailBlobID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedThumbnailSize: UInt32 = 50
        let expectedEncryptionKey: Data = BytesUtility.generateRandomBytes(length: 32)!
        
        let msg: GroupVideoMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.duration = expectedDuration
        msg.videoBlobID = expectedVideoBlobID
        msg.videoSize = expectedVideoSize
        msg.thumbnailBlobID = expectedThumbnailBlobID
        msg.thumbnailSize = expectedThumbnailSize
        msg.encryptionKey = expectedEncryptionKey
        
        let result: GroupVideoMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedDuration, result?.duration)
        XCTAssertTrue(expectedVideoBlobID.elementsEqual((result?.videoBlobID)!))
        XCTAssertEqual(expectedVideoSize, result?.videoSize)
        XCTAssertTrue(expectedThumbnailBlobID.elementsEqual((result?.thumbnailBlobID)!))
        XCTAssertEqual(expectedThumbnailSize, result?.thumbnailSize)
        XCTAssertTrue(expectedEncryptionKey.elementsEqual((result?.encryptionKey)!))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
    
    func testGroupDeliveryReceiptMessage() throws {
        let expectedGroupID: Data = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR1"
        let expectedReceiptType: ReceiptType = .received
        let expectedReceiptMessageIDs: [Data] = [
            BytesUtility.generateRandomBytes(length: 8)!,
            BytesUtility.generateRandomBytes(length: 8)!,
        ]
        
        let msg: GroupDeliveryReceiptMessage = abstractMessage(
            expectedFromIdentity,
            expectedToIdentity,
            expectedMessageID,
            expectedPushFromName,
            expectedDate,
            expectedDeliveryDate,
            expectedDelivered,
            expectedUserAck,
            expectedSendUserAck,
            expectedNonce,
            expectedFlags,
            expectedReceivedAfterInitialQueueSend
        )
        
        msg.groupID = expectedGroupID
        msg.groupCreator = expectedGroupCreator
        msg.receiptType = expectedReceiptType.rawValue
        msg.receiptMessageIDs = expectedReceiptMessageIDs
        
        let result: GroupDeliveryReceiptMessage? = try encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
              
        XCTAssertTrue(expectedGroupID.elementsEqual((result?.groupID)!))
        XCTAssertEqual(expectedGroupCreator, result?.groupCreator)
        XCTAssertEqual(expectedReceiptType.rawValue, result?.receiptType)
        XCTAssertEqual(2, result?.receiptMessageIDs.count)
        XCTAssertTrue(expectedReceiptMessageIDs[0].elementsEqual(result?.receiptMessageIDs[0] as! Data))
        XCTAssertTrue(expectedReceiptMessageIDs[1].elementsEqual(result?.receiptMessageIDs[1] as! Data))

        XCTAssertEqual(expectedFromIdentity, result?.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result?.toIdentity)
        XCTAssertEqual(expectedMessageID, result?.messageID)
        XCTAssertEqual(expectedPushFromName, result?.pushFromName)
        XCTAssertEqual(expectedDate, result?.date)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedDelivered), result?.delivered)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedUserAck), result?.userAck)
        XCTAssertEqual(NSNumber(booleanLiteral: expectedSendUserAck), result?.sendUserAck)
        XCTAssertTrue(expectedNonce.elementsEqual((result?.nonce)!))
        XCTAssertEqual(NSNumber(integerLiteral: expectedFlags), (result?.flags)!)
        XCTAssertFalse((result?.receivedAfterInitialQueueSend)!)
        XCTAssertNil(try XCTUnwrap(result) as? QuotedMessageProtocol)
    }
}
