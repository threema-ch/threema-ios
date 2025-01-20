//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import XCTest
@testable import ThreemaFramework

class MediatorMessageProtocolTests: XCTestCase {

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
        let expectedNonce = MockData.generateMessageNonce()

        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockData.deviceGroupKeys)
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
        
        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockData.deviceGroupKeys)
        let envelopeOutgoingMessage = mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
            type: 0x01,
            body: message,
            messageID: 1,
            receiverIdentity: "ECHOECHO",
            createdAt: createdAt,
            nonce: MockData.generateMessageNonce(),
            deviceID: MockData.deviceID.paddedLittleEndian()
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
