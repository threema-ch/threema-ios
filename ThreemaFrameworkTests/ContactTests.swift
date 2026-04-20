import ThreemaEssentials

import ThreemaMacros
import ThreemaProtocols
import XCTest

@testable import ThreemaFramework

final class ContactTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.preparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testSaveAndImplicitReload() throws {
        let expectedIdentity = ThreemaIdentity("MEMBER01")
        let expectedPublicKey = BytesUtility.generatePublicKey()

        // Setup initial contact entity in DB

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity.rawValue,
                verificationLevel: .unverified
            )
            contactEntity.publicNickname = "fritzberg"
            contactEntity.setFirstName(to: "Fritz", sortOrderFirstName: true)
            contactEntity.setLastName(to: "Berg", sortOrderFirstName: true)
            contactEntity.contactState = .inactive
            contactEntity.workContact = NSNumber(booleanLiteral: true)
        }

        let contact = Contact(contactEntity: contactEntity)

        // Check contact properties before changing

        XCTAssertEqual(expectedIdentity, contact.identity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)
        XCTAssertEqual("fritzberg", contact.publicNickname)
        XCTAssertEqual("Fritz", contact.firstName)
        XCTAssertEqual("Berg", contact.lastName)
        XCTAssertEqual(ContactEntity.ContactState.inactive, contact.state)
        XCTAssertTrue(contact.isWorkContact)

        // Change contact entity properties in DB

        let entityManager = testDatabase.entityManager
        entityManager.performAndWaitSave {
            contactEntity.setFirstName(to: "Fritzli", sortOrderFirstName: true)
            contactEntity.setLastName(to: "Bergli", sortOrderFirstName: true)
            contactEntity.publicNickname = "fritzlibergli"
            contactEntity.contactVerificationLevel = .serverVerified
            contactEntity.contactState = .active
            contactEntity.workContact = NSNumber(booleanLiteral: false)
        }

        // Check changed contact properties

        XCTAssertEqual(expectedIdentity, contactEntity.threemaIdentity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)
        XCTAssertEqual("fritzlibergli", contact.publicNickname)
        XCTAssertEqual("Fritzli", contact.firstName)
        XCTAssertEqual("Bergli", contact.lastName)
        XCTAssertEqual(ContactEntity.ContactState.active, contact.state)
        XCTAssertFalse(contact.isWorkContact)
    }

    func testIdentityMismatch() throws {
        let expectedIdentity = ThreemaIdentity("MEMBER01")
        let expectedPublicKey = BytesUtility.generatePublicKey()

        // Setup initial contact entity in DB

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity.rawValue,
                verificationLevel: .unverified
            )
        }

        let contact = Contact(contactEntity: contactEntity)

        // Check contact properties before changing

        XCTAssertEqual(expectedIdentity, contact.identity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)

        // Change contact entity properties in DB

        let entityManager = testDatabase.entityManager
        entityManager.performAndWaitSave {
            contactEntity.setIdentity(to: "CONTACT1", sortOrderFirstName: true)
        }

        // Check changed contact properties

        XCTAssertEqual(expectedIdentity, contact.identity)
        XCTAssertEqual(expectedPublicKey, contact.publicKey)
        XCTAssertTrue(ddLoggerMock.exists(message: "Identity or public key mismatch"))
    }

    func testEqualTo() throws {
        var contact1: ContactEntity!
        var contact2: ContactEntity!
        var contact3: ContactEntity!

        dbPreparer.save {
            contact1 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "CONTACT1",
                verificationLevel: .fullyVerified
            )
            contact1.publicNickname = "#1"
            contact1.setFirstName(to: "first name one", sortOrderFirstName: true)
            contact1.setLastName(to: "last name one", sortOrderFirstName: true)
            contact1.contactState = .inactive
            contact1.workContact = NSNumber(booleanLiteral: true)

            contact2 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "CONTACT2"
            )
            contact2.publicNickname = "#2"
            contact2.setFirstName(to: "first name second", sortOrderFirstName: true)
            contact2.setLastName(to: "last name second", sortOrderFirstName: true)
            contact2.contactState = .inactive
            contact2.workContact = NSNumber(booleanLiteral: false)

            contact3 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "CONTACT3"
            )
            contact3.publicNickname = "#3"
            contact3.setFirstName(to: "first name third", sortOrderFirstName: true)
            contact3.setLastName(to: "last name third", sortOrderFirstName: true)
            contact3.contactState = .inactive
            contact3.workContact = NSNumber(booleanLiteral: false)
        }

        let c1 = Contact(contactEntity: contact1)
        let c2 = Contact(contactEntity: contact2)
        let c3 = Contact(contactEntity: contact2)

        XCTAssertTrue(c2.isEqual(to: c3))

        XCTAssertFalse(c1.isEqual(to: c2))
        XCTAssertFalse(c1.isEqual(to: c3))

        let s1: Set<Contact> = Set([c1, c2])
        let s2: Set<Contact> = Set([c3, c1])

        XCTAssertTrue(s1.contactsEqual(to: s2))

        let c4 = Contact(contactEntity: contact3)
        let s3: Set<Contact> = Set([c1, c3, c4])

        XCTAssertFalse(s1.contactsEqual(to: s3))
    }

    func testDeleteContactEntity() throws {
        let contactEntity = dbPreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: "ECHOECHO"
        )

        let contact = Contact(contactEntity: contactEntity)

        XCTAssertFalse(contact.willBeDeleted)

        dbPreparer.save {
            dbPreparer.delete(object: contactEntity)
        }

        let expect = expectation(description: "Give time for deletion")
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 2)

        XCTAssertTrue(contact.willBeDeleted)
    }
    
    func testDisplayName() {
        dbPreparer.save {
            let contactEntity = self.dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "CONTACT1",
                verificationLevel: .fullyVerified
            )

            let assertDisplayNameEquals = { (s: String) in
                var c: Contact

                contactEntity.contactState = .active
                c = Contact(contactEntity: contactEntity)
                XCTAssertEqual(c.displayName, s)
                XCTAssertEqual(contactEntity.displayName, c.displayName)
                
                contactEntity.contactState = .inactive
                c = Contact(contactEntity: contactEntity)
                XCTAssertEqual(c.displayName, "\(s) (\(#localize("inactive")))")
                XCTAssertEqual(contactEntity.displayName, c.displayName)

                contactEntity.contactState = .invalid
                c = Contact(contactEntity: contactEntity)
                XCTAssertEqual(c.displayName, "\(s) (\(#localize("invalid")))")
                XCTAssertEqual(contactEntity.displayName, c.displayName)
            }

            // Sort order first name is true
            UserSettings.shared().displayOrderFirstName = true

            assertDisplayNameEquals("CONTACT1")

            contactEntity.publicNickname = ""
            assertDisplayNameEquals("CONTACT1")
            
            contactEntity.publicNickname = "🙂"
            assertDisplayNameEquals("~🙂")

            contactEntity.setFirstName(to: "First", sortOrderFirstName: UserSettings.shared().displayOrderFirstName)
            assertDisplayNameEquals("First")

            contactEntity.setLastName(to: "Last Name", sortOrderFirstName: UserSettings.shared().displayOrderFirstName)
            assertDisplayNameEquals("First Last Name")

            contactEntity.setFirstName(to: nil, sortOrderFirstName: UserSettings.shared().displayOrderFirstName)
            assertDisplayNameEquals("Last Name")

            // Sort order first name is false
            UserSettings.shared().displayOrderFirstName = false

            contactEntity.setFirstName(to: "First", sortOrderFirstName: UserSettings.shared().displayOrderFirstName)
            contactEntity.setLastName(to: "Last Name", sortOrderFirstName: UserSettings.shared().displayOrderFirstName)
            assertDisplayNameEquals("Last Name First")
            
            // reset to default in case of further tests depending on the default
            UserSettings.shared().displayOrderFirstName = true
        }
    }

    func testContactFeatureMask() async {
        dbPreparer.save {
            self.dbPreparer.createContact(identity: "ECHOECHO")
        }

        let em = testDatabase.entityManager

        for flag in ThreemaProtocols.Common_CspFeatureMaskFlag.allCases {
            let contactEntity = await em.performSave {
                let contactEntity = em.entityFetcher.contactEntity(for: "ECHOECHO")
                contactEntity?.setFeatureMask(to: flag.rawValue)
                return contactEntity
            }

            XCTAssertEqual(contactEntity?.featureMask.intValue, flag.rawValue)
        }
    }
}
