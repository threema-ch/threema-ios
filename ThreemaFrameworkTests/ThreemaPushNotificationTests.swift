import XCTest

@testable import ThreemaFramework

final class ThreemaPushNotificationTests: XCTestCase {
    
    func testCompleteDictionaryDecoding() throws {
        let from = "ABCDEFGH"
        let messageID = "0123456789abcdef"
        
        let payload = [
            "cmd": "newmsg",
            "from": from,
            "messageId": messageID,
            "voip": "true",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        XCTAssertEqual(threemaPushNotification.from, from)
        XCTAssertEqual(threemaPushNotification.messageID, messageID)
        let actualVoip = try XCTUnwrap(threemaPushNotification.voip)
        XCTAssertTrue(actualVoip)
    }
    
    // MARK: Command tests
    
    func testNewMessageCommandDictionaryDecoding() throws {
        let payload = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        XCTAssertEqual(threemaPushNotification.command, ThreemaPushNotification.Command.newMessage)
    }
    
    func testNewGroupMessageCommandDictionaryDecoding() throws {
        let payload = [
            "cmd": "newgroupmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        XCTAssertEqual(threemaPushNotification.command, ThreemaPushNotification.Command.newGroupMessage)
    }
    
    // MARK: Voip tests
    
    func testMissingVoipDictionaryDecoding() throws {
        let payload = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        XCTAssertNil(threemaPushNotification.voip)
    }
    
    func testFalseVoipStringDictionaryDecoding() throws {
        let payload = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "false",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        let actualVoip = try XCTUnwrap(threemaPushNotification.voip)
        XCTAssertFalse(actualVoip)
    }
    
    func testTrueVoipStringDictionaryDecoding() throws {
        let payload = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        let actualVoip = try XCTUnwrap(threemaPushNotification.voip)
        XCTAssertTrue(actualVoip)
    }
    
    func testTrueVoipDictionaryDecoding() throws {
        let payload: [String: Any] = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": true,
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        let actualVoip = try XCTUnwrap(threemaPushNotification.voip)
        XCTAssertTrue(actualVoip)
    }
    
    func testFalseVoipDictionaryDecoding() throws {
        let payload: [String: Any] = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": false,
        ]
        
        let threemaPushNotification = try ThreemaPushNotification(from: payload)
        
        let actualVoip = try XCTUnwrap(threemaPushNotification.voip)
        XCTAssertFalse(actualVoip)
    }
    
    // MARK: Failing payloads
    
    func testWrongCommandKeyDictionaryDecoding() throws {
        let payload = [
            "cmds": "newmsg",
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
                
        XCTAssertThrowsError(try ThreemaPushNotification(from: payload)) { error in
            XCTAssertEqual(
                error as? ThreemaPushNotificationError,
                .keyNotFoundOrTypeMissmatch(ThreemaPushNotificationDictionary.commandKey)
            )
        }
    }
    
    func testMissingCommandDictionaryDecoding() throws {
        let payload = [
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
                
        XCTAssertThrowsError(try ThreemaPushNotification(from: payload)) { error in
            XCTAssertEqual(
                error as? ThreemaPushNotificationError,
                .keyNotFoundOrTypeMissmatch(ThreemaPushNotificationDictionary.commandKey)
            )
        }
    }
    
    func testWrongCommandValueDictionaryDecoding() throws {
        let command = "foobar"
        
        let payload = [
            "cmd": command,
            "from": "ABCDEFGH",
            "messageId": "0123456789abcdef",
            "voip": "true",
        ]
                
        XCTAssertThrowsError(try ThreemaPushNotification(from: payload)) { error in
            XCTAssertEqual(error as? ThreemaPushNotificationError, .unknownCommand(command))
        }
    }
    
    func testMissingMessageIDDictionaryDecoding() throws {
        let payload = [
            "cmd": "newmsg",
            "from": "ABCDEFGH",
            "voip": "true",
        ]
                
        XCTAssertThrowsError(try ThreemaPushNotification(from: payload)) { error in
            XCTAssertEqual(
                error as? ThreemaPushNotificationError,
                .keyNotFoundOrTypeMissmatch(ThreemaPushNotificationDictionary.messageIDKey)
            )
        }
    }
}
