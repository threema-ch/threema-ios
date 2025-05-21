//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class MediatorMessageProcessorTests: XCTestCase {
    
    private var mmp: MediatorMessageProcessor?
    private var deviceGroupKeys: DeviceGroupKeys!
    private var taskManagerMock: TaskManagerMock!

    override func setUpWithError() throws {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        taskManagerMock = TaskManagerMock()

        deviceGroupKeys = DeviceGroupKeys(
            dgpk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgrk: Data(base64Encoded: "BivETNngWPWYxad+ogDb8Q4ZWha1piBk/TLGsW5zojs=")!,
            dgdik: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgsddk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgtsk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            deviceGroupIDFirstByteHex: "a1"
        )

        mmp = MediatorMessageProcessor(
            deviceGroupKeys: deviceGroupKeys,
            deviceID: Data([1]),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys) as AnyObject,
            userSettings: UserSettingsMock(),
            taskManager: taskManagerMock,
            socketProtocolDelegate: self,
            messageProcessorDelegate: self
        )
    }

    func testProcessServerHello() {
        let messageServerHello =
            Data(
                base64Encoded: "EAAAABIg9qLdSffS2qq535/mtuhZ5q1gJNsKqJn+N3Htw9iF1T4aIK8HiqwGXebzJ7OFwd5TNL936Kh/OfD3JF6x+O9ovnKp"
            )!

        var type = UInt8()
        let result = mmp?.process(
            message: messageServerHello,
            messageType: &type,
            receivedAfterInitialQueueSend: false,
            maxDeviceSlots: nil
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(0x11, result?[0])
        XCTAssertEqual(type, MediatorMessageProtocol.MediatorMessageType.serverHello.rawValue)
    }

    func testMaxDeviceSlots() throws {
        var serverInfo = D2m_ServerInfo()
        serverInfo.maxDeviceSlots = 3
        
        var messageServerInfo = Data(BytesUtility.padding(
            [MediatorMessageProtocol.MediatorMessageType.serverInfo.rawValue],
            pad: 0x00,
            length: 4 // MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH
        ))
        try messageServerInfo.append(serverInfo.serializedData())
        
        var type = UInt8()
        var maxDeviceSlots = NSNumber()
        let result = mmp?.process(
            message: messageServerInfo,
            messageType: &type,
            receivedAfterInitialQueueSend: false,
            maxDeviceSlots: &maxDeviceSlots
        )
        
        XCTAssertNil(result)
        XCTAssertEqual(type, MediatorMessageProtocol.MediatorMessageType.serverInfo.rawValue)
        XCTAssertEqual(maxDeviceSlots, 3)
    }
    
    func testProcessUndefinedType() {
        let message = Data([0x01])
        
        var type = UInt8()
        let result = mmp?.process(
            message: message,
            messageType: &type,
            receivedAfterInitialQueueSend: false,
            maxDeviceSlots: nil
        )

        XCTAssertNil(result)
    }
    
    func testProcessReflectAck() {
        let reflectID = MockData.generateReflectID()
        let reflectedAt = Date().millisecondsSince1970
        
        var message = Data(
            bytes: [MediatorMessageProtocol.MediatorMessageType.reflectAck.rawValue, 0x00, 0x00, 0x00],
            count: 4
        ) // Common header
        message.append([0x00, 0x00, 0x00, 0x00], count: 4) // Reserved
        message.append(reflectID)
        message.append(reflectedAt.littleEndianData)

        let expec = expectation(description: "test")

        NotificationCenter.default.addObserver(
            forName: TaskManager.mediatorMessageAckObserverName(reflectID: reflectID),
            object: nil, queue: nil
        ) { notification in
            XCTAssertEqual(reflectedAt.date, notification.userInfo?[reflectID] as? Date)

            expec.fulfill()
        }

        var type = UInt8()
        let result = mmp?.process(
            message: message,
            messageType: &type,
            receivedAfterInitialQueueSend: false,
            maxDeviceSlots: nil
        )

        wait(for: [expec], timeout: 3)

        XCTAssertNil(result)
    }
    
    func testProcessReflected() {

        let expectedReflectedMessage =
            Data(
                base64Encoded: "ggAAABAAAABrAgAAOdq1mnABAAByNgeC13aJplJlX+cv+jaZcTO0oUpqDeZNu9uFLPxl1L4e5tm1R7ZSBo8LFBhEnfP6ckPX1Eqyonirb3JPDrMRXiu6ugDjVPrzUPY3K50hG4sKIjXvUVvX/zMWkefgCcJtRPjFcB+5Tjv5VBKQ/25unQl3TCCSSmtDBftU+vDdAEnfJ3ReaQ8poPd9bg=="
            )!

        var type = UInt8()
        let result = mmp?.process(
            message: expectedReflectedMessage,
            messageType: &type,
            receivedAfterInitialQueueSend: false,
            maxDeviceSlots: nil
        )

        XCTAssertNil(result)
        XCTAssertEqual(type, MediatorMessageProtocol.MediatorMessageType.reflected.rawValue)
        XCTAssertEqual(1, taskManagerMock.addedTasks.count)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { $0 as? TaskDefinitionReceiveReflectedMessage != nil }.count
        )

        let task = taskManagerMock.addedTasks
            .first { $0 as? TaskDefinitionReceiveReflectedMessage != nil } as! TaskDefinitionReceiveReflectedMessage
        XCTAssertEqual(task.reflectedMessage, expectedReflectedMessage)
    }
}

// MARK: - SocketProtocolDelegate

extension MediatorMessageProcessorTests: SocketProtocolDelegate {
    func didConnect() { }
    
    func didRead(_ data: Data, tag: Int16) { }
    
    func didDisconnect(errorCode: Int) { }
}

// MARK: - MessageProcessorDelegate

extension MediatorMessageProcessorTests: MessageProcessorDelegate {
    func beforeDecode() { }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        // no-op
    }
    
    func incomingMessageStarted(_ message: AbstractMessage) { }
    
    func incomingMessageChanged(_ message: AbstractMessage, baseMessage: BaseMessageEntity) { }

    func incomingMessageFinished(_ message: AbstractMessage) { }
    
    func incomingMessageFailed(_ message: BoxedMessage) {
        // no-op
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        // no-op
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        // no-op
    }

    func outgoingMessageFinished(_ message: AbstractMessage) { }

    func readMessage(inConversations: Set<ConversationEntity>?) {
        // no-op
    }

    func taskQueueEmpty() { }
    
    func chatQueueDry() { }
    
    func reflectionQueueDry() { }
        
    func processTypingIndicator(_ message: TypingIndicatorMessage) { }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: @escaping ((any MessageProcessorDelegate)?) -> Void,
        onError: @escaping (any Error, (any MessageProcessorDelegate)?) -> Void
    ) {
        // no-op
    }
}
