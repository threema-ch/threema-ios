//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

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
    
    private func encodeDecode<T: AbstractMessage>(message: T) -> T? {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encodeRootObject(message)
        archiver.finishEncoding()

        let unarchiver = NSKeyedUnarchiver(forReadingWith: Data(bytes: data.mutableBytes, count: data.count))
        return try? unarchiver.decodeTopLevelObject() as? T
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
        
        let result: BoxAudioMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxBallotCreateMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxBallotVoteMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxFileMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxImageMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxLocationMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxTextMessage? = encodeDecode(message: msg)
        
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
        
        let result: BoxVideoMessage? = encodeDecode(message: msg)
        
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
    }
    
    func testContactDeletePhotoMessage() throws {
        let msg: ContactDeletePhotoMessage = abstractMessage(
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
        
        let result: ContactDeletePhotoMessage? = encodeDecode(message: msg)
        
        XCTAssertNotNil(result)
        
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
        
        let result: ContactSetPhotoMessage? = encodeDecode(message: msg)
        
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
    }
    
    func testDeliveryReceiptMessage() throws {
        let expectedReceiptType: UInt8 = 1
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
        
        let result: DeliveryReceiptMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupAudioMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupBallotCreateMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupBallotVoteMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupCreateMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupFileMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupImageMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupRenameMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupLocationMessage? = encodeDecode(message: msg)
        
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
        
        let result: GroupSetPhotoMessage? = encodeDecode(message: msg)
        
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
    }
    
    func testGroupTextMessage() {
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
        
        let result: GroupTextMessage? = encodeDecode(message: msg)

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
        
        let result: GroupVideoMessage? = encodeDecode(message: msg)
        
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
    }
}
