//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import ThreemaEssentials
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

private enum TestData {
    static let testSessionID = DHSessionID()
    static let testEphemeralPublicKey = Data(BytesUtility.toBytes(
        hexString: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    )!)
    static let testDhType = CspE2eFs_Encapsulated.DHType.fourdh
    static let testCounter = UInt64(1)
    static let testMessage = Data(
        BytesUtility.toBytes(hexString: "0148656c6c6f")!
    )
    static let testMessageID = Data(
        BytesUtility.toBytes(hexString: "0001020304050607")!
    )
    static let testMessageIDUInt64 = UInt64(0x01_0203_0405_0607).bigEndian
    static let testCause = CspE2eFs_Reject.Cause.unknownSession
    static let testGroupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: ThreemaIdentity("ABCDEFGH"))
}

class ForwardSecurityDataInitTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_Envelope.OneOf_Content
                .init_p(CspE2eFs_Init.with {
                    $0.fssk = TestData.testEphemeralPublicKey
                    $0.supportedVersion = ThreemaEnvironment.fsVersion
                })
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataInit(
            sessionID: TestData.testSessionID,
            versionRange: ThreemaEnvironment.fsVersion,
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
            versionRange: ThreemaEnvironment.fsVersion,
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
    var testProtobufMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_Envelope.OneOf_Content
                .accept(CspE2eFs_Accept.with {
                    $0.fssk = TestData.testEphemeralPublicKey
                    $0.supportedVersion = ThreemaEnvironment.fsVersion
                })
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataAccept(
            sessionID: TestData.testSessionID,
            version: ThreemaEnvironment.fsVersion,
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
            version: ThreemaEnvironment.fsVersion,
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
    var testProtobufMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.encapsulated = CspE2eFs_Encapsulated.with {
                $0.dhType = TestData.testDhType
                $0.counter = TestData.testCounter
                $0.encryptedInner = TestData.testMessage
                $0.appliedVersion = UInt32(CspE2eFs_Version.v11.rawValue)
                $0.offeredVersion = UInt32(CspE2eFs_Version.v11.rawValue)
            }
        }
    }
    
    var testProtobufGroupMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.encapsulated = CspE2eFs_Encapsulated.with {
                $0.dhType = TestData.testDhType
                $0.counter = TestData.testCounter
                $0.groupIdentity = TestData.testGroupIdentity.asCommonGroupIdentity
                $0.encryptedInner = TestData.testMessage
                $0.appliedVersion = UInt32(CspE2eFs_Version.v11.rawValue)
                $0.offeredVersion = UInt32(CspE2eFs_Version.v11.rawValue)
            }
        }
    }
    
    func testValidData() {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            groupIdentity: nil,
            offeredVersion: .v11,
            appliedVersion: .v11,
            message: TestData.testMessage
        )
        assertEqualsTestProperties(data: data, groupIdentity: nil)
    }
    
    func testValidGroupData() {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            groupIdentity: TestData.testGroupIdentity,
            offeredVersion: .v11,
            appliedVersion: .v11,
            message: TestData.testMessage
        )
        assertEqualsTestProperties(data: data, groupIdentity: TestData.testGroupIdentity)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataMessage.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataMessage, groupIdentity: nil)
    }
    
    func testFromProtobufWithEmptyGroupIdentity() throws {
        // As we have no group information we treat it as if it was an 1:1 message
        var localTestProtobufMessage = testProtobufMessage
        localTestProtobufMessage.encapsulated.groupIdentity = Common_GroupIdentity()
        let rawMessage = try localTestProtobufMessage.serializedData()
        let data = try ForwardSecurityDataMessage.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataMessage, groupIdentity: nil)
    }
    
    func testFromGroupProtobuf() throws {
        let rawMessage = try testProtobufGroupMessage.serializedData()
        let data = try ForwardSecurityDataMessage.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataMessage, groupIdentity: TestData.testGroupIdentity)
    }
    
    func testToProtobufMessage() throws {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            groupIdentity: nil,
            offeredVersion: .v11,
            appliedVersion: .v11,
            message: TestData.testMessage
        )
        let generatedProtobufMessage = try data.toProtobuf()
        
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    func testToProtobufGroupMessage() throws {
        let data = ForwardSecurityDataMessage(
            sessionID: TestData.testSessionID,
            type: TestData.testDhType,
            counter: TestData.testCounter,
            groupIdentity: TestData.testGroupIdentity,
            offeredVersion: .v11,
            appliedVersion: .v11,
            message: TestData.testMessage
        )
        let generatedProtobufMessage = try data.toProtobuf()
        
        XCTAssertEqual(generatedProtobufMessage, try testProtobufGroupMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataMessage, groupIdentity: GroupIdentity?) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testDhType, data.type)
        XCTAssertEqual(TestData.testCounter, data.counter)
        XCTAssertEqual(TestData.testMessage, data.message)
        XCTAssertEqual(groupIdentity, data.groupIdentity)
    }
}

class ForwardSecurityDataRejectTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.reject = CspE2eFs_Reject.with {
                $0.messageID = TestData.testMessageIDUInt64
                $0.cause = TestData.testCause
            }
        }
    }
    
    var testProtobufGroupMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.reject = CspE2eFs_Reject.with {
                $0.messageID = TestData.testMessageIDUInt64
                $0.groupIdentity = TestData.testGroupIdentity.asCommonGroupIdentity
                $0.cause = TestData.testCause
            }
        }
    }
    
    func testValidData() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            messageID: TestData.testMessageID,
            groupIdentity: nil,
            cause: TestData.testCause
        )
        assertEqualsTestProperties(data: data, groupIdentity: nil)
    }
    
    func testValidGroupData() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            messageID: TestData.testMessageID,
            groupIdentity: TestData.testGroupIdentity,
            cause: TestData.testCause
        )
        assertEqualsTestProperties(data: data, groupIdentity: TestData.testGroupIdentity)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataReject.fromProtobuf(rawProtobufMessage: rawMessage)

        let actualForwardSecurityDataReject = try XCTUnwrap(data as? ForwardSecurityDataReject)
        assertEqualsTestProperties(data: actualForwardSecurityDataReject, groupIdentity: nil)
    }
    
    func testFromProtobufWithEmptyGroupIdentity() throws {
        // As we have no group information we treat it as if it was an 1:1 message
        var localTestProtobufMessage = testProtobufMessage
        localTestProtobufMessage.reject.groupIdentity = Common_GroupIdentity()
        
        let rawMessage = try localTestProtobufMessage.serializedData()
        let data = try ForwardSecurityDataReject.fromProtobuf(rawProtobufMessage: rawMessage)
        
        let actualForwardSecurityDataReject = try XCTUnwrap(data as? ForwardSecurityDataReject)
        assertEqualsTestProperties(data: actualForwardSecurityDataReject, groupIdentity: nil)
    }
    
    func testFromGroupProtobuf() throws {
        let rawMessage = try testProtobufGroupMessage.serializedData()
        let data = try ForwardSecurityDataReject.fromProtobuf(rawProtobufMessage: rawMessage)

        let actualForwardSecurityDataReject = try XCTUnwrap(data as? ForwardSecurityDataReject)
        assertEqualsTestProperties(data: actualForwardSecurityDataReject, groupIdentity: TestData.testGroupIdentity)
    }
    
    func testToProtobufMessage() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            messageID: TestData.testMessageID,
            groupIdentity: nil,
            cause: TestData.testCause
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    func testToProtobufGroupMessage() throws {
        let data = try ForwardSecurityDataReject(
            sessionID: TestData.testSessionID,
            messageID: TestData.testMessageID,
            groupIdentity: TestData.testGroupIdentity,
            cause: TestData.testCause
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufGroupMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataReject, groupIdentity: GroupIdentity?) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
        XCTAssertEqual(TestData.testMessageID, data.messageID)
        XCTAssertEqual(TestData.testCause, data.cause)
        XCTAssertEqual(groupIdentity, data.groupIdentity)
    }
}

class ForwardSecurityDataTerminateTests: XCTestCase {
    var testProtobufMessage: CspE2eFs_Envelope {
        CspE2eFs_Envelope.with {
            $0.sessionID = TestData.testSessionID.value
            $0.content = CspE2eFs_Envelope.OneOf_Content
                .terminate(CspE2eFs_Terminate())
        }
    }
    
    func testValidData() {
        let data = ForwardSecurityDataTerminate(sessionID: TestData.testSessionID, cause: .unknownSession)
        assertEqualsTestProperties(data: data)
    }
    
    func testFromProtobuf() throws {
        let rawMessage = try testProtobufMessage.serializedData()
        let data = try ForwardSecurityDataTerminate.fromProtobuf(rawProtobufMessage: rawMessage)
        assertEqualsTestProperties(data: data as! ForwardSecurityDataTerminate)
    }
    
    func testToProtobufMessage() throws {
        let data = ForwardSecurityDataTerminate(
            sessionID: TestData.testSessionID,
            cause: .unknownSession
        )
        let generatedProtobufMessage = try data.toProtobuf()
        XCTAssertEqual(generatedProtobufMessage, try testProtobufMessage.serializedData())
    }
    
    private func assertEqualsTestProperties(data: ForwardSecurityDataTerminate) {
        XCTAssertEqual(TestData.testSessionID, data.sessionID)
    }
}
