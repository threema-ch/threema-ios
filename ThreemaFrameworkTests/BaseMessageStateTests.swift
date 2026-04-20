import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BaseMessageStateTests: XCTestCase {
    
    private var databasePreparer: TestDatabasePreparer!
    private var conversation: ConversationEntity!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
    }
    
    // MARK: - messageState
    
    func testOwnState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        XCTAssertEqual(.sending, baseMessage.messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(.sent, baseMessage.messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.delivered, baseMessage.messageState)

        baseMessage.read = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.failed, baseMessage.messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(.failed, baseMessage.messageState)
    }
    
    func testOtherState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: Date(timeIntervalSinceNow: -100)
            )
        }
        
        XCTAssertEqual(.received, baseMessage.messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(.received, baseMessage.messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.received, baseMessage.messageState)

        baseMessage.read = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(.read, baseMessage.messageState)
    }
}
