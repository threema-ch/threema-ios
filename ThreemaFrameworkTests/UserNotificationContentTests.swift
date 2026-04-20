import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class UserNotificationContentTests: XCTestCase {
    private var databasePreparer: TestDatabasePreparer!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
    }
    
    func testNoInformation() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertNil(userNotificationContent.cmd)
    }
    
    func testThreemaPushMsg() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
                "nick": "red99",
            ])

        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }

    func testThreemaPushGroupMsg() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newgroupmsg",
                "nick": "red99",
            ])

        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }

    func testAbstractMessage() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.abstractMessage = BoxTextMessage()
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }
    
    func testAbstractGroupMessage() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.abstractMessage = GroupTextMessage()
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }
    
    func testMessage() throws {
        let expectedIdendity = "ECHOECHO"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 32)!
        
        var textMessage: TextMessageEntity!
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: expectedMessageID,
                identity: expectedIdendity
            )
            databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = contact
                
                    textMessage = self.databasePreparer.createTextMessage(
                        conversation: conversation,
                        text: "Hello world!",
                        date: Date(),
                        delivered: false,
                        id: expectedMessageID,
                        isOwn: true,
                        read: false,
                        sent: false,
                        userack: false,
                        sender: contact,
                        remoteSentDate: nil
                    )
                }
        }
        
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.baseMessage = textMessage
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }

    func testGroupMessage() throws {
        let expectedIdendity = "ECHOECHO"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 32)!
        
        var textMessage: TextMessageEntity!
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: expectedMessageID,
                identity: expectedIdendity
            )
            let group = databasePreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: expectedIdendity
            )
            databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = group.groupID
                    conversation.contact = contact
                
                    textMessage = self.databasePreparer.createTextMessage(
                        conversation: conversation,
                        text: "Hello world!",
                        date: Date(),
                        delivered: false,
                        id: expectedMessageID,
                        isOwn: true,
                        read: false,
                        sent: false,
                        userack: false,
                        sender: nil,
                        remoteSentDate: nil
                    )
                }
        }

        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.baseMessage = textMessage
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }
}
