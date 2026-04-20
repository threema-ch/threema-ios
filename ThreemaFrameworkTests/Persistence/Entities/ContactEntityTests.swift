import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class ContactEntityTests: XCTestCase {
    
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

        let cnContactID = "cnContactID"
        let createdAt = Date.now
        let csi = "csi"
        let department = "department"
        let featureMask = 2024
        let firstName = "Testy"
        let forwardSecurityState = 0
        let hidden = 0
        let identity = "TESTERID"
        let imageData = BytesUtility.generateGroupID()
        let importStatus = 0
        let jobTitle = "Tester"
        let lastName = "McTestface"
        let profilePictureBlobID = "RandomID"
        let profilePictureSended = 0
        let profilePictureUpload = Date.now
        let publicKey = BytesUtility.generatePublicKey()
        let publicNickname = "Testy"
        let readReceipts = 0
        let sortIndex = 0
        let sortInitial = "T"
        let state = 0
        let typingIndicators = 0
        let verificationLevel = 0
        let verifiedEmail = "testy@testing.test"
        let verifiedMobileNo = "0123456789"
        let workContact = 0
        
        // Act
        
        let contactImage = entityManager.performAndWait {
            ImageDataEntity(context: testDatabase.context.main, data: Data(), height: 1, width: 1)
        }
        
        let conversations: Set<ConversationEntity> = entityManager.performAndWaitSave {
            [entityManager.entityCreator.conversationEntity()]
        }

        let groupConversations: Set<ConversationEntity> = entityManager.performAndWaitSave {
            [entityManager.entityCreator.conversationEntity()]
        }
        
        let reactions: Set<MessageReactionEntity> = entityManager.performAndWaitSave {
            let message = entityManager.entityCreator.textMessageEntity(
                text: ":)",
                in: conversations.first!,
                setLastUpdate: false
            )
            return [entityManager.entityCreator.messageReactionEntity(reaction: "😂", message: message)]
        }
        let rejectedMessages: Set<TextMessageEntity> = entityManager.performAndWaitSave {
            [
                entityManager.entityCreator.textMessageEntity(
                    text: ":)",
                    in: conversations.first!,
                    setLastUpdate: false
                ),
                entityManager.entityCreator.textMessageEntity(
                    text: ":(",
                    in: conversations.first!,
                    setLastUpdate: false
                ),
            ]
        }

        // Count only encrypt calls while saving `ContactEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let contactEntity = entityManager.performAndWaitSave {
            ContactEntity(
                context: testDatabase.context.main,
                cnContactID: cnContactID,
                createdAt: createdAt,
                csi: csi,
                department: department,
                featureMask: featureMask,
                firstName: firstName,
                forwardSecurityState: forwardSecurityState as NSNumber,
                hidden: hidden as NSNumber,
                identity: identity,
                imageData: imageData,
                importStatus: importStatus as NSNumber,
                jobTitle: jobTitle,
                lastName: lastName,
                profilePictureBlobID: profilePictureBlobID,
                profilePictureSended: profilePictureSended as NSNumber,
                profilePictureUpload: profilePictureUpload,
                publicKey: publicKey,
                publicNickname: publicNickname,
                readReceipts: readReceipts as NSNumber,
                sortIndex: sortIndex as NSNumber,
                sortInitial: sortInitial,
                state: state as NSNumber,
                typingIndicators: typingIndicators as NSNumber,
                verificationLevel: verificationLevel as NSNumber,
                verifiedEmail: verifiedEmail,
                verifiedMobileNo: verifiedMobileNo,
                workContact: workContact as NSNumber,
                contactImage: contactImage,
                conversations: conversations,
                groupConversations: groupConversations,
                reactions: reactions,
                rejectedMessages: rejectedMessages,
                sortOrderFirstName: true
            )
        }

        let fetchedContactEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: contactEntity.objectID) as? ContactEntity
        )

        // Assert
        XCTAssertEqual(cnContactID, fetchedContactEntity.cnContactID)
        XCTAssertEqual(createdAt, fetchedContactEntity.createdAt)
        XCTAssertEqual(csi, fetchedContactEntity.csi)
        XCTAssertEqual(department, fetchedContactEntity.department)
        XCTAssertEqual(featureMask as NSNumber, fetchedContactEntity.featureMask)
        XCTAssertEqual(firstName, fetchedContactEntity.firstName)
        XCTAssertEqual(forwardSecurityState as NSNumber, fetchedContactEntity.forwardSecurityState)
        XCTAssertEqual(NSNumber(value: hidden).boolValue, fetchedContactEntity.isHidden)
        XCTAssertEqual(identity, fetchedContactEntity.identity)
        XCTAssertEqual(imageData, fetchedContactEntity.imageData)
        XCTAssertEqual(importStatus, fetchedContactEntity.contactImportStatus.rawValue)
        XCTAssertEqual(jobTitle, fetchedContactEntity.jobTitle)
        XCTAssertEqual(lastName, fetchedContactEntity.lastName)
        XCTAssertEqual(profilePictureBlobID, fetchedContactEntity.profilePictureBlobID)
        XCTAssertEqual(NSNumber(value: profilePictureSended).boolValue, fetchedContactEntity.profilePictureSent)
        XCTAssertEqual(
            profilePictureUpload,
            fetchedContactEntity.profilePictureUpload
        )
        XCTAssertEqual(publicKey, fetchedContactEntity.publicKey)
        XCTAssertEqual(publicNickname, fetchedContactEntity.publicNickname)
        XCTAssertEqual(ContactEntity.ReadReceipt(rawValue: readReceipts), fetchedContactEntity.readReceipt)
        XCTAssertEqual(ContactEntity.ContactState(rawValue: state), fetchedContactEntity.contactState)
        XCTAssertEqual(ContactEntity.TypingIndicator(rawValue: typingIndicators), fetchedContactEntity.typingIndicator)
        XCTAssertEqual(
            ContactEntity.VerificationLevel(rawValue: verificationLevel),
            fetchedContactEntity.contactVerificationLevel
        )
        XCTAssertEqual(verifiedEmail, fetchedContactEntity.verifiedEmail)
        XCTAssertEqual(verifiedMobileNo, fetchedContactEntity.verifiedMobileNo)
        XCTAssertEqual(workContact as NSNumber, fetchedContactEntity.workContact)
        XCTAssertEqual(contactImage, fetchedContactEntity.contactImage)
        XCTAssertEqual(conversations, fetchedContactEntity.conversations)
        XCTAssertEqual(groupConversations, fetchedContactEntity.groupConversations)
        XCTAssertEqual(reactions, fetchedContactEntity.reactions)
        XCTAssertEqual(rejectedMessages, fetchedContactEntity.rejectedMessages)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 13)

            // Test faulting
            testDatabase.context.main.refresh(fetchedContactEntity, mergeChanges: false)

            XCTAssertEqual(cnContactID, fetchedContactEntity.cnContactID)
            XCTAssertEqual(createdAt.timeIntervalSince1970, fetchedContactEntity.createdAt?.timeIntervalSince1970)
            XCTAssertEqual(featureMask as NSNumber, fetchedContactEntity.featureMask)
            XCTAssertEqual(forwardSecurityState as NSNumber, fetchedContactEntity.forwardSecurityState)
            XCTAssertEqual(imageData, fetchedContactEntity.imageData)
            XCTAssertEqual(importStatus, fetchedContactEntity.contactImportStatus.rawValue)
            XCTAssertEqual(profilePictureBlobID, fetchedContactEntity.profilePictureBlobID)
            XCTAssertEqual(NSNumber(value: profilePictureSended).boolValue, fetchedContactEntity.profilePictureSent)
            XCTAssertEqual(
                profilePictureUpload.timeIntervalSince1970,
                fetchedContactEntity.profilePictureUpload?.timeIntervalSince1970
            )
            XCTAssertEqual(publicKey, fetchedContactEntity.publicKey)
            XCTAssertEqual(
                ContactEntity.VerificationLevel(rawValue: verificationLevel),
                fetchedContactEntity.contactVerificationLevel
            )
            XCTAssertEqual(verifiedEmail, fetchedContactEntity.verifiedEmail)
            XCTAssertEqual(verifiedMobileNo, fetchedContactEntity.verifiedMobileNo)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 13)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 13)
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

        let identity = "TESTERID"
        let publicKey = BytesUtility.generatePublicKey()
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            ContactEntity(
                context: testDatabase.context.main,
                identity: identity,
                publicKey: publicKey,
                sortOrderFirstName: true
            )
        }
        
        let fetchedContactEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: contactEntity.objectID) as? ContactEntity
        )
        // Assert
        XCTAssertEqual(identity, fetchedContactEntity.identity)
        XCTAssertEqual(publicKey, fetchedContactEntity.publicKey)
    }
}
