//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

private enum TestData {
    static let testSessionID = DHSessionID()
    static let testEphemeralPublicKey = Data(
        BytesUtility
            .toBytes(hexString: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!
    )
    static let testDhType = CspE2eFs_ForwardSecurityEnvelope.Message.DHType.fourdh
    static let testCounter = UInt64(1)
    static let testMessage = Data(
        BytesUtility
            .toBytes(hexString: "0148656c6c6f")!
    )
    static let testMessageID = Data(
        BytesUtility
            .toBytes(hexString: "0001020304050607")!
    )
    static let testMessageIDUInt64 = UInt64(0x01_0203_0405_0607).bigEndian
    static let testCause = CspE2eFs_ForwardSecurityEnvelope.Reject.Cause.unknownSession
}

class ForwardSecurityDataInitTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_ForwardSecurityEnvelope {
        CspE2eFs_ForwardSecurityEnvelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content
                .init_p(CspE2eFs_ForwardSecurityEnvelope.Init.with {
                    $0.ephemeralPublicKey = TestData.testEphemeralPublicKey
                })
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataInit(
            sessionID: TestData.testSessionID,
            ephemeralPublicKey: TestData.testEphemeralPublicKey
        )
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataInit.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataInit)
    }
    
    func testToProtobufMessage() throws {
        let data = try ForwardSecurityDataInit(
            sessionID: TestData.testSessionID,
            ephemeralPublicKey: TestData.testEphemeralPublicKey
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataInit) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testEphemeralPublicKey, data.ephemeralPublicKey)
    }
}

class ForwardSecurityDataAcceptTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_ForwardSecurityEnvelope {
        CspE2eFs_ForwardSecurityEnvelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content
                .accept(CspE2eFs_ForwardSecurityEnvelope.Accept.with {
                    $0.ephemeralPublicKey = TestData.testEphemeralPublicKey
                })
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataAccept(
            sessionID: TestData.testSessionID,
            ephemeralPublicKey: TestData.testEphemeralPublicKey
        )
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataAccept.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataAccept)
    }
    
    func testToProtobufMessage() throws {
        let data = try ForwardSecurityDataAccept(
            sessionID: TestData.testSessionID,
            ephemeralPublicKey: TestData.testEphemeralPublicKey
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataAccept) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testEphemeralPublicKey, data.ephemeralPublicKey)
    }
}

class ForwardSecurityDataMessageTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_ForwardSecurityEnvelope {
        CspE2eFs_ForwardSecurityEnvelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content
                .message(CspE2eFs_ForwardSecurityEnvelope.Message.with {
                    $0.dhType = TestData.testDhType
                    $0.counter = TestData.testCounter
                    $0.message = TestData.testMessage
                })
        }
    }
    
    func testValidData() {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            message: TestData.testMessage
        )
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataMessage.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataMessage)
    }
    
    func testToProtobufMessage() throws {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            message: TestData.testMessage
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataMessage) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testDhType, data.type)
        XCTAssertEqual(TestData.testCounter, data.counter)
        XCTAssertEqual(TestData.testMessage, data.message)
    }
}

class ForwardSecurityDataRejectTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_ForwardSecurityEnvelope {
        CspE2eFs_ForwardSecurityEnvelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content
                .reject(CspE2eFs_ForwardSecurityEnvelope.Reject.with {
                    $0.rejectedMessageID = TestData.testMessageIDUInt64
                    $0.cause = TestData.testCause
                })
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            rejectedMessageID: TestData.testMessageID,
            cause: TestData.testCause
        )
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataReject.fromProtobuf(rawProtobufMessage: rawMessage)
        print(BytesUtility.toHexString(bytes: [UInt8](rawMessage)))
        assertEqualsTestProperties(data: data as! ForwardSecurityDataReject)
    }
    
    func testToProtobufMessage() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            rejectedMessageID: TestData.testMessageID,
            cause: TestData.testCause
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataReject) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testMessageID, data.rejectedMessageID)
        XCTAssertEqual(TestData.testCause, data.cause)
    }
}

class ForwardSecurityDataTerminateTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_ForwardSecurityEnvelope {
        CspE2eFs_ForwardSecurityEnvelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content
                .terminate(CspE2eFs_ForwardSecurityEnvelope.Terminate())
        }
    }
    
    func testValidData() {
        let data = ForwardSecurityDataTerminate(sessionID: TestData.testSessionID)
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataTerminate.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataTerminate)
    }
    
    func testToProtobufMessage() throws {
        let data = ForwardSecurityDataTerminate(
            sessionID: TestData.testSessionID
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataTerminate) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
    }
}
