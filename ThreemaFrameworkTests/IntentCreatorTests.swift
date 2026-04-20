import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class IntentCreatorTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!
    
    override func setUp() {
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.preparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDown() {
        DDLog.remove(ddLoggerMock)
    }

    func testAllowedDonateInteractionForIncomingMessage() throws {
        let entityManager = testDatabase.entityManager
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.complete.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = testDatabase.preparer
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01"
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNotNil(interaction)
        XCTAssertNotNil(groupInteraction)
    }
    
    func testNotAllowedDonateInteractionForIncomingMessage() throws {
        let entityManager = testDatabase.entityManager
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.balanced.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = testDatabase.preparer
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01"
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNil(interaction)
        XCTAssertNil(groupInteraction)
        XCTAssertTrue(ddLoggerMock.exists(message: "Donations for incoming interactions are disabled by the user"))
    }
    
    func testDoNotDonateForPrivateChats1() throws {
        let entityManager = testDatabase.entityManager

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.balanced.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = testDatabase.preparer
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01"
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                conversation.changeCategory(to: .private)
                _ = contact1.conversations!.insert(conversation)
                
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNil(interaction)
        XCTAssertNil(groupInteraction)
    }
    
    func testDoNotDonateForPrivateChats2() throws {
        let entityManager = testDatabase.entityManager

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.complete.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = testDatabase.preparer
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01"
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                _ = contact1.conversations!.insert(conversation)
                
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                    
                    conversation.changeCategory(to: .private)
                }
            )
        }

        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNotNil(interaction)
        XCTAssertNil(groupInteraction)
    }
}
