import ThreemaEssentials
import ThreemaMacros
import XCTest

@testable import Threema
@testable import ThreemaFramework

class URLHandlerTests: XCTestCase {
    
    private var testDatabase: TestDatabase!
    private var ddLoggerMock: DDLoggerMock!
    
    override func setUp() {
        super.setUp()
        
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        testDatabase = TestDatabase()
        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }
    
    override func tearDown() {
        super.tearDown()
        
        DDLog.remove(ddLoggerMock)
    }
    
    func testUnknownHost() async {
        let businessInjector = BusinessInjectorMock(
            entityManager: testDatabase.entityManager
        )
        
        let url = URL(string: "threema://newAction")!
        URLHandler(businessInjector: businessInjector).handle(url)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[URLHandler] Failed to handle URL: Unknown host (newAction). Aborting URL handling.")
        )
    }
    
    func testAddContact() async throws {
        let expectedSenderIdentity = "ABCDEFGH"
        let expectedFromName = "ABCD EFGH"

        // Create contact for mocking
        let entityManager = testDatabase.entityManager
        testDatabase.preparer.createContact(
            publicKey: Data([1]),
            identity: expectedSenderIdentity,
            nickname: expectedFromName
        )
        let contact = entityManager.entityFetcher.contactEntity(for: expectedSenderIdentity)
        let contactStoreMock = ContactStoreMock(callOnCompletion: true, contact)
        let businessInjector = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: testDatabase.entityManager
        )

        let url = URL(string: "threema://add?id=ABCDEFGH")!
        URLHandler(businessInjector: businessInjector)
            .handle(url)
        
        XCTAssertTrue(contactStoreMock.addContactCalls.contains(expectedSenderIdentity))
    }

    func testAddContactWithOwnIdentity() async {
        let expectedSenderIdentity = "ECHOECHO"
        let expectedFromName = "Echo Echo"

        // Create contact for mocking
        let entityManager = testDatabase.entityManager
        testDatabase.preparer.createContact(
            publicKey: Data([1]),
            identity: expectedSenderIdentity,
            nickname: expectedFromName
        )
        let contact = entityManager.entityFetcher.contactEntity(for: expectedSenderIdentity)
        let contactStoreMock = ContactStoreMock(
            callOnCompletion: true,
            contact,
            errorHandler: NSError(domain: "", code: 0, userInfo: nil)
        )
        let businessInjector = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: testDatabase.entityManager
        )

        let url = URL(string: "threema://add?id=ECHOECHO")!
        URLHandler(businessInjector: businessInjector)
            .handle(url)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[URLHandler] Failed to handle URL: Can't add own identity. Aborting add identity handling."
                )
        )
        XCTAssertFalse(contactStoreMock.addContactCalls.contains(expectedSenderIdentity))
    }

    func testAddContactWithInvalidIdentity() async {
        let expectedSenderIdentity = "ABCDEFGH"
        
        let contactStoreMock = ContactStoreMock(
            callOnCompletion: true,
            errorHandler: NSError(domain: "", code: 0, userInfo: nil)
        )
        let businessInjector = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: testDatabase.entityManager
        )
        
        let url = URL(string: "threema://add?id=ABCDEFGH")!
        URLHandler(businessInjector: businessInjector)
            .handle(url)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[URLHandler] Failed to handle URL: Add contact failed. Aborting add identity handling."
                )
        )
        XCTAssertFalse(contactStoreMock.addContactCalls.contains(expectedSenderIdentity))
    }

    func testThreemaDotID() async throws {
        throw XCTSkip("This test is calling AppDelegate function, but that's missing in AppTestDelegate")

        let expectedSenderIdentity = "ABCDEFGH"
        let expectedFromName = "ABCD EFGH"

        // Create contact for mocking
        let entityManager = testDatabase.entityManager
        testDatabase.preparer.createContact(
            publicKey: Data([1]),
            identity: expectedSenderIdentity,
            nickname: expectedFromName
        )
        let contact = entityManager.entityFetcher.contactEntity(for: expectedSenderIdentity)
        let contactStoreMock = ContactStoreMock(callOnCompletion: true, contact)
        let businessInjector = BusinessInjectorMock(
            contactStore: contactStoreMock,
            entityManager: testDatabase.entityManager
        )

        let url = URL(string: "https://threema.id/ABCDEFGH")!
        URLHandler(businessInjector: businessInjector)
            .handle(url)
        XCTAssertTrue(contactStoreMock.addContactCalls.contains(expectedSenderIdentity))
    }

    func testLicense() async {
        let businessInjector = BusinessInjectorMock(
            entityManager: testDatabase.entityManager
        )

        let url = URL(string: "threema://license")!
        URLHandler(businessInjector: businessInjector)
            .handle(url)

        DDLog.sharedInstance.flushLog()
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[URLHandler] Failed to handle URL: No license for private app. Aborting license handling."
                )
        )
    }
}
