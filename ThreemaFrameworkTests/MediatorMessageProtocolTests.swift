import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class MediatorMessageProtocolTests: XCTestCase {

    func testIsMediatorMessage() {
        let messages = [
            [Data([0x00]), false],
            [Data([0x00, 0x00, 0x00]), false],
            [Data([0x00, 0x00, 0x00, 0x00]), false],
            [Data([0x00, 0x00, 0x00, 0x00, 0x3D]), false],
            [Data([0x01, 0x00, 0x00, 0x00]), true],
            [Data([0x01, 0x00, 0x00, 0x00, 0x3D]), true],
        ]
        
        for message in messages {
            XCTAssertEqual(message[1] as! Bool, MediatorMessageProtocol.isMediatorMessage(message[0] as! Data))
        }
    }
    
    func testProxyMessage() {
        let message = Data([1])

        let result = MediatorMessageProtocol.addProxyCommonHeader(message)
        
        XCTAssertEqual(5, result.count)
        XCTAssertEqual(
            MediatorMessageProtocol.MediatorMessageType(rawValue: result[0]),
            MediatorMessageProtocol.MediatorMessageType.proxy
        )
    }

    func testGetEncryptDecryptEnvelopeForIncomingMessage() {
        let expectedMessage = Data(repeating: 0x01, count: 1)
        let expectedCreatedAt = Date()
        let expectedNonce = BytesUtility.generateMessageNonce()

        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockMultiDevice.deviceGroupKeys)
        let envelopeIncomigMessage = mediatorMessageProtocol.getEnvelopeForIncomingMessage(
            type: 0x01,
            body: expectedMessage,
            messageID: 1,
            senderIdentity: "ECHOECHO",
            createdAt: expectedCreatedAt,
            nonce: expectedNonce
        )
        let encryptedMessage = mediatorMessageProtocol.encodeEnvelope(envelope: envelopeIncomigMessage)
        
        XCTAssertNotNil(encryptedMessage.reflectID)
        XCTAssertNotNil(encryptedMessage.reflectMessage)

        // Extract reflect ID, reflect Message and decrypt
        let reflectID = encryptedMessage.reflectMessage!.subdata(in: 8..<12)
        let envelope = mediatorMessageProtocol.decryptEnvelope(
            data: encryptedMessage.reflectMessage!.subdata(in: 12..<encryptedMessage.reflectMessage!.count)
        )

        XCTAssertEqual(encryptedMessage.reflectID, reflectID)
        XCTAssertEqual(envelope?.incomingMessage.body, Data([1]))
        XCTAssertEqual(envelope?.incomingMessage.createdAt, UInt64(expectedCreatedAt.millisecondsSince1970))
        XCTAssertEqual(envelope?.incomingMessage.messageID, 1)
        XCTAssertEqual(envelope?.incomingMessage.senderIdentity, "ECHOECHO")
        XCTAssertEqual(envelope?.incomingMessage.nonce, expectedNonce)
    }

    func testGetEncryptDecryptEnvelopeForOutgoingMessage() {
        let message = Data([1])
        let createdAt = Date()
        
        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockMultiDevice.deviceGroupKeys)
        let envelopeOutgoingMessage = mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
            type: 0x01,
            body: message,
            messageID: 1,
            receiverIdentity: "ECHOECHO",
            createdAt: createdAt,
            nonce: BytesUtility.generateMessageNonce(),
            deviceID: MockMultiDevice.deviceID.paddedLittleEndian()
        )
        let encryptedMessage = mediatorMessageProtocol.encodeEnvelope(envelope: envelopeOutgoingMessage)
        
        XCTAssertNotNil(encryptedMessage.reflectID)
        XCTAssertNotNil(encryptedMessage.reflectMessage)

        // Extract reflect ID, reflect Message and decrypt
        let reflectID = encryptedMessage.reflectMessage!.subdata(in: 8..<12)
        let envelope = mediatorMessageProtocol.decryptEnvelope(
            data: encryptedMessage.reflectMessage!.subdata(in: 12..<encryptedMessage.reflectMessage!.count)
        )

        XCTAssertEqual(encryptedMessage.reflectID, reflectID)
        XCTAssertEqual(envelope?.outgoingMessage.body, Data([1]))
        XCTAssertEqual(envelope?.outgoingMessage.createdAt, UInt64(createdAt.millisecondsSince1970))
        XCTAssertEqual(envelope?.outgoingMessage.messageID, 1)
        XCTAssertEqual(envelope?.outgoingMessage.conversation.contact, "ECHOECHO")
    }
}
