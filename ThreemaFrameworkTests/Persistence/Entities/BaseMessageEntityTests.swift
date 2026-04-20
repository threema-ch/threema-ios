import CoreData
import Foundation
import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class BaseMessageEntityTests: XCTestCase {
        
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

        let date = Date.now
        let deletedAt = Date.now
        let delivered = true
        let deliveryDate = Date.now
        let flags = 0
        let forwardSecurityMode = 0
        let id = BytesUtility.generateMessageID()
        let isCreatedFromWeb = true
        let isOwn = true
        let lastEditedAt = Date.now
        let read = true
        let readDate = Date.now
        let remoteSentDate = Date.now
        let sendFailed = true
        let sent = true
        let webRequestID = "TESTID"

        // Act
        
        let groupDeliveryReceipts = [GroupDeliveryReceipt(
            identity: "TESTER02",
            deliveryReceiptType: .acknowledged,
            date: .now
        )]
        
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let sender = entityManager.performAndWait {
            ContactEntity(
                context: testDatabase.context.main,
                identity: "TESTER01",
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: false
            )
        }
        
        let rejectedMembers: Set<ContactEntity> = entityManager.performAndWaitSave {
            [
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER02",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER03",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER04",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
            ]
        }

        // Count only encrypt calls while saving `BaseMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let baseMessageEntity = entityManager.performAndWaitSave {
            BaseMessageEntity(
                entity: NSEntityDescription.entity(forEntityName: "Message", in: testDatabase.context.main)!,
                insertInto: testDatabase.context.main,
                date: date,
                deletedAt: deletedAt,
                delivered: delivered,
                deliveryDate: deliveryDate,
                flags: flags as NSNumber,
                forwardSecurityMode: forwardSecurityMode,
                groupDeliveryReceipts: groupDeliveryReceipts,
                id: id,
                isCreatedFromWeb: isCreatedFromWeb,
                isOwn: isOwn,
                lastEditedAt: lastEditedAt,
                read: read,
                readDate: readDate,
                remoteSentDate: remoteSentDate,
                sendFailed: sendFailed,
                sent: sent,
                webRequestID: webRequestID,
                conversation: conversation,
                distributedMessages: nil,
                distributionListMessage: nil,
                historyEntries: nil,
                messageMarkers: nil,
                reactions: nil,
                rejectedBy: rejectedMembers,
                sender: sender
            )
        }
        
        testDatabase.remoteSecretCryptoMock.decryptCalls = 0

        let fetchedBaseMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: baseMessageEntity.objectID) as? BaseMessageEntity
        )
        
        // Assert
        XCTAssertEqual(date, fetchedBaseMessageEntity.date)
        XCTAssertEqual(deletedAt, fetchedBaseMessageEntity.deletedAt)
        XCTAssertEqual(delivered, fetchedBaseMessageEntity.delivered.boolValue)
        XCTAssertEqual(deliveryDate, fetchedBaseMessageEntity.deliveryDate)
        XCTAssertEqual(flags as NSNumber, fetchedBaseMessageEntity.flags)
        XCTAssertEqual(forwardSecurityMode as NSNumber, fetchedBaseMessageEntity.forwardSecurityMode)
        XCTAssertEqual(groupDeliveryReceipts, fetchedBaseMessageEntity.groupDeliveryReceipts)
        XCTAssertEqual(id, fetchedBaseMessageEntity.id)
        XCTAssertEqual(isCreatedFromWeb, fetchedBaseMessageEntity.isCreatedFromWeb?.boolValue)
        XCTAssertEqual(isOwn, fetchedBaseMessageEntity.isOwn.boolValue)
        XCTAssertEqual(lastEditedAt, fetchedBaseMessageEntity.lastEditedAt)
        XCTAssertEqual(read, fetchedBaseMessageEntity.read.boolValue)
        XCTAssertEqual(readDate, fetchedBaseMessageEntity.readDate)
        XCTAssertEqual(remoteSentDate, fetchedBaseMessageEntity.remoteSentDate)
        XCTAssertEqual(sendFailed, fetchedBaseMessageEntity.sendFailed?.boolValue)
        XCTAssertEqual(sent, fetchedBaseMessageEntity.sent.boolValue)
        XCTAssertEqual(webRequestID, fetchedBaseMessageEntity.webRequestID)
        XCTAssertEqual(conversation.objectID, fetchedBaseMessageEntity.conversation.objectID)
        XCTAssertEqual(rejectedMembers.count, fetchedBaseMessageEntity.rejectedBy?.count)
        XCTAssertEqual(sender.objectID, fetchedBaseMessageEntity.sender?.objectID)
        XCTAssertFalse(fetchedBaseMessageEntity.userack.boolValue)
        XCTAssertNil(fetchedBaseMessageEntity.userackDate)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 12)

            // Test faulting
            testDatabase.context.main.refresh(fetchedBaseMessageEntity, mergeChanges: false)

            XCTAssertEqual(deletedAt.timeIntervalSince1970, fetchedBaseMessageEntity.deletedAt?.timeIntervalSince1970)
            XCTAssertEqual(delivered, fetchedBaseMessageEntity.delivered.boolValue)
            XCTAssertEqual(
                deliveryDate.timeIntervalSince1970,
                fetchedBaseMessageEntity.deliveryDate?.timeIntervalSince1970
            )
            XCTAssertEqual(flags as NSNumber, fetchedBaseMessageEntity.flags)
            XCTAssertEqual(forwardSecurityMode as NSNumber, fetchedBaseMessageEntity.forwardSecurityMode)
            XCTAssertEqual(groupDeliveryReceipts.count, fetchedBaseMessageEntity.groupDeliveryReceipts?.count)
            XCTAssertEqual(isCreatedFromWeb, fetchedBaseMessageEntity.isCreatedFromWeb?.boolValue)
            XCTAssertEqual(
                lastEditedAt.timeIntervalSince1970,
                fetchedBaseMessageEntity.lastEditedAt?.timeIntervalSince1970
            )
            XCTAssertEqual(sendFailed, fetchedBaseMessageEntity.sendFailed?.boolValue)
            XCTAssertEqual(sent, fetchedBaseMessageEntity.sent.boolValue)
            XCTAssertEqual(webRequestID, fetchedBaseMessageEntity.webRequestID)
            XCTAssertFalse(fetchedBaseMessageEntity.userack.boolValue)
            XCTAssertNil(fetchedBaseMessageEntity.userackDate)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 12)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 12)
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

        let id = BytesUtility.generateMessageID()
        let isOwn = true

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let baseMessageEntity = entityManager.performAndWaitSave {
            BaseMessageEntity(
                entity: NSEntityDescription.entity(forEntityName: "Message", in: testDatabase.context.main)!,
                insertInto: testDatabase.context.main,
                id: id,
                isOwn: isOwn,
                conversation: conversation
            )
        }
        
        let fetchedBaseMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: baseMessageEntity.objectID) as? BaseMessageEntity
        )
        
        // Assert
        XCTAssertEqual(id, fetchedBaseMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedBaseMessageEntity.isOwn.boolValue)
        XCTAssertEqual(conversation.objectID, fetchedBaseMessageEntity.conversation.objectID)
    }
}
