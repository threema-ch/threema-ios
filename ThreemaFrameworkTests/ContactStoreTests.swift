import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class ContactStoreTests: XCTestCase {

    private var testDatabase: TestDatabase!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testAddWorkContactWithIdentity() throws {
        let expectedIdentity = "TESTER01"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedFirstName = "Test"
        let expectedLastName = "Tester"
        let expectedCsi = "Csi"
        let expectedJobTitle = "JobTitle"
        let expectedDepartment = "Department"

        let userSettingsMock = UserSettingsMock()
        let em = testDatabase.entityManager
        let contactStore = ContactStore(userSettings: userSettingsMock, entityManager: em)

        let identity = contactStore.addWorkContact(
            with: expectedIdentity,
            publicKey: expectedPublicKey,
            firstname: expectedFirstName,
            lastname: expectedLastName,
            csi: expectedCsi,
            jobTitle: expectedJobTitle,
            department: expectedDepartment,
            featureMask: 0,
            acquaintanceLevel: .direct,
            entityManager: em,
            contactSyncer: nil
        )

        XCTAssertEqual(expectedIdentity, identity)
        let contactEntity = try XCTUnwrap(em.entityFetcher.contactEntity(for: identity!))
        XCTAssertEqual(expectedPublicKey, contactEntity.publicKey)
        XCTAssertEqual(expectedFirstName, contactEntity.firstName)
        XCTAssertEqual(expectedLastName, contactEntity.lastName)
        XCTAssertEqual(expectedCsi, contactEntity.csi)
        XCTAssertEqual(expectedJobTitle, contactEntity.jobTitle)
        XCTAssertEqual(expectedDepartment, contactEntity.department)
        XCTAssertTrue((userSettingsMock.workIdentities ?? []).contains(expectedIdentity))
        XCTAssertTrue(
            (userSettingsMock.profilePictureRequestList ?? [])
                .contains(where: { $0 as? String == expectedIdentity })
        )
    }
    
    func testAddUnknownContactWithIdentityBlockUnknown() throws {
        let expectedIdentity = "TESTER01"

        let userSettingsMock = UserSettingsMock(blockUnknown: true)
        let em = testDatabase.entityManager
        let contactStore = ContactStore(userSettings: userSettingsMock, entityManager: em)
        
        let expect = expectation(description: "Give time to fetch public key")
        
        var error: Error?
        contactStore.fetchPublicKey(
            for: expectedIdentity,
            acquaintanceLevel: .direct,
            entityManager: em,
            ignoreBlockUnknown: false
        ) { _ in
            expect.fulfill()
        } onError: { err in
            error = err
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 2)
        XCTAssertEqual(error?.localizedDescription, "Message received from unknown contact and block contacts is on")
    }
    
    func testAddSpecialContactWithIdentityBlockUnknown() throws {
        let specialContact: PredefinedContacts = .threemaPush
        
        guard specialContact.isSpecialContact else {
            XCTFail("This test requires a special contact")
            return
        }

        let userSettingsMock = UserSettingsMock(blockUnknown: true)
        let em = testDatabase.entityManager
        let contactStore = ContactStore(userSettings: userSettingsMock, entityManager: em)
        
        let expect = expectation(description: "Give time to fetch public key")
                
        var receivedPublicKey: Data?
        contactStore.fetchPublicKey(
            for: specialContact.identity?.rawValue,
            acquaintanceLevel: .direct,
            entityManager: em,
            ignoreBlockUnknown: false
        ) { publicKey in
            receivedPublicKey = publicKey
            expect.fulfill()
        } onError: { _ in
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
        XCTAssertTrue(try specialContact.isSamePublicKey(XCTUnwrap(receivedPublicKey)))
    }
    
    func testAddPredefinedContactWithIdentityBlockUnknown() throws {
        let predefinedContact: PredefinedContacts = .support
        
        guard !predefinedContact.isSpecialContact else {
            XCTFail("This test requires a non special contact")
            return
        }
        
        guard let predefinedContactIdentity = predefinedContact.identity else {
            XCTFail("Identity not found for predefined contact: \(predefinedContact)")
            return
        }

        let userSettingsMock = UserSettingsMock(blockUnknown: true)
        let em = testDatabase.entityManager
        let contactStore = ContactStore(userSettings: userSettingsMock, entityManager: em)
        
        let expect = expectation(description: "Give time to fetch public key")
                
        var receivedPublicKey: Data?
        contactStore.fetchPublicKey(
            for: predefinedContactIdentity.rawValue,
            acquaintanceLevel: .direct,
            entityManager: em,
            ignoreBlockUnknown: false
        ) { publicKey in
            receivedPublicKey = publicKey
            expect.fulfill()
        } onError: { _ in
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
        XCTAssertNil(receivedPublicKey)
    }

    func testUpdateContactWithIdentity() throws {
        let expectedIdentity = "TESTER01"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedFirstName = "Dirsty"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity
            )
            contact.imageData = Data([0])
        }

        let em = testDatabase.entityManager

        let contactStore = ContactStore(
            userSettings: UserSettingsMock(),
            entityManager: em
        )
        contactStore.updateContact(
            withIdentity: expectedIdentity,
            avatar: nil,
            firstName: expectedFirstName,
            lastName: nil
        )

        let contactEntity = try XCTUnwrap(em.entityFetcher.contactEntity(for: expectedIdentity))
        XCTAssertEqual(expectedIdentity, contactEntity.identity)
        XCTAssertEqual(expectedPublicKey, contactEntity.publicKey)
        XCTAssertNil(contactEntity.imageData)
        XCTAssertEqual(expectedFirstName, contactEntity.firstName)
        XCTAssertNil(contactEntity.lastName)
    }
    
    func testUpdateContactStatus() throws {
        let expectedIdentity = "TESTER01"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedStatus = ContactEntity.ContactState.active

        let dbPreparer = testDatabase.preparer
        var savedContact: ContactEntity?
        dbPreparer.save {
            savedContact = dbPreparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity,
                state: .inactive
            )
        }

        let em = testDatabase.entityManager

        let contactStore = ContactStore(
            userSettings: UserSettingsMock(),
            entityManager: em
        )
        
        XCTAssertEqual(.inactive, savedContact?.contactState)
        
        contactStore.updateStateToActive(for: savedContact!, entityManager: em)

        let contactEntity = try XCTUnwrap(em.entityFetcher.contactEntity(for: expectedIdentity))
        XCTAssertEqual(expectedIdentity, contactEntity.identity)
        XCTAssertEqual(expectedPublicKey, contactEntity.publicKey)
        XCTAssertNil(contactEntity.firstName)
        XCTAssertNil(contactEntity.lastName)
        XCTAssertEqual(expectedStatus, contactEntity.contactState)
    }
}
