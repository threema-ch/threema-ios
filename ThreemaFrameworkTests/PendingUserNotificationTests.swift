import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class PendingUserNotificationTests: XCTestCase {

    func testEncodeDecode() throws {
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedKey = "sender\(expectedMessageID.hexString)"
        let expectedText = "123"

        let boxTextMessage = BoxTextMessage()
        boxTextMessage.messageID = expectedMessageID
        boxTextMessage.text = "123"

        let pendingUserNotification = PendingUserNotification(key: expectedKey)
        pendingUserNotification.abstractMessage = boxTextMessage

        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(pendingUserNotification, forKey: "key")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let decodedObject = try unarchiver.decodeTopLevelObject(of: [PendingUserNotification.self], forKey: "key")

        XCTAssertTrue(decodedObject is PendingUserNotification)
        let decodedPendingUserNotification = try XCTUnwrap(decodedObject as? PendingUserNotification)
        XCTAssertEqual(decodedPendingUserNotification.key, expectedKey)

        XCTAssertTrue(decodedPendingUserNotification.abstractMessage is BoxTextMessage)
        let decodedBoxTextMessage = try XCTUnwrap(decodedPendingUserNotification.abstractMessage as? BoxTextMessage)
        XCTAssertEqual(decodedBoxTextMessage.messageID, expectedMessageID)
        XCTAssertEqual(decodedBoxTextMessage.text, expectedText)
    }
}
