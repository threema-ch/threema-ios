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

import Foundation
@testable import ThreemaFramework

class ServerConnectorMock: NSObject, ServerConnectorProtocol {

    var reflectMessageCalls = [Data]()
    var sendMessageCalls = [BoxedMessage]()
    var completedProcessingMessageCalls = [BoxedMessage]()

    var reflectMessageClosure: ((_ message: Data) -> NSError?)?
    var sendMessageClosure: ((_ message: BoxedMessage) -> Bool)?

    var connectionStateDelegate: ConnectionStateDelegate?
    var taskExecutionTransactionDelegate: TaskExecutionTransactionDelegate?
    var messageProcessorDelegate: MessageProcessorDelegate?
    var messageListenerDelegate: MessageListenerDelegate?

    var waitMillisecondsBeforSend = 5
    let sendQueue = DispatchQueue(label: "ch.threema.ThreemaFrameworkTests.ServerConnectorMock")

    init(connectionState: ConnectionState, deviceID: Data?, deviceGroupKeys: DeviceGroupKeys?) {
        self.connectionState = connectionState
        self.deviceID = deviceID
        self.deviceGroupKeys = deviceGroupKeys
    }
    
    convenience init(connectionState: ConnectionState) {
        self.init(connectionState: connectionState, deviceID: nil, deviceGroupKeys: nil)
    }
    
    override convenience init() {
        self.init(connectionState: .disconnected)
    }

    // MARK: - ServerConnectorProtocol

    var backgroundEntityManagerForMessageProcessing: NSObject?

    var connectionState: ConnectionState

    var deviceID: Data?
    
    var maximumNumberOfDeviceSlots: NSNumber?

    var deviceGroupKeys: DeviceGroupKeys?

    func name(for connectionState: ConnectionState) -> String {
        "unknown"
    }

    var isAppInBackground = false

    func connect(initiator: ConnectionInitiator) {
        // no-op
    }

    func connectWait(initiator: ConnectionInitiator) {
        // no-op
    }

    func connectWaitDoNotUnblockIncomingMessages(initiator: ConnectionInitiator) {
        // no-op
    }
    
    func unblockIncomingMessages() {
        // no-op
    }

    func disconnect(initiator: ConnectionInitiator) {
        // no-op
    }

    func disconnectWait(initiator: ConnectionInitiator) -> Bool {
        true
    }
    
    func reconnect() {
        // no-op
    }

    func deactivateMultiDevice() {
        // no-op
    }

    func registerConnectionStateDelegate(delegate: ConnectionStateDelegate) {
        connectionStateDelegate = delegate
    }

    func unregisterConnectionStateDelegate(delegate: ConnectionStateDelegate) {
        connectionStateDelegate = nil
    }

    // MARK: ConnectionStateDelegate

    func changed(connectionState state: ConnectionState) { }
    
    func registerTaskExecutionTransactionDelegate(delegate: TaskExecutionTransactionDelegate) {
        taskExecutionTransactionDelegate = delegate
    }
    
    func unregisterTaskExecutionTransactionDelegate(delegate: TaskExecutionTransactionDelegate) {
        taskExecutionTransactionDelegate = nil
    }
    
    func transactionResponse(_ messageType: UInt8, reason: Data?) {
        taskExecutionTransactionDelegate?.transactionResponse(messageType, reason: reason)
    }
    
    func reflectMessage(_ message: Data) -> Error? {
        reflectMessageCalls.append(message)

        return reflectMessageClosure?(message) ?? (connectionState == .loggedIn ? nil : ThreemaError.threemaError(
            "Not logged in",
            withCode: ThreemaProtocolError.notLoggedIn.rawValue
        ))
    }
    
    func send(_ message: BoxedMessage) -> Bool {
        sendMessageCalls.append(message)

        if let sendMessageClosure {
            return sendMessageClosure(message)
        }

        if connectionState == .loggedIn {
            // TODO: Should wait here to simulate poor network, but it those not work
            sendQueue.asyncAfter(deadline: .now() + .milliseconds(waitMillisecondsBeforSend)) {
                NotificationCenter.default.post(
                    name: TaskManager.chatMessageAckObserverName(
                        messageID: message.messageID,
                        toIdentity: message.toIdentity
                    ),
                    object: nil
                )
            }
            return true
        }

        return false
    }
    
    func completedProcessingMessage(_ boxmsg: BoxedMessage) -> Bool {
        completedProcessingMessageCalls.append(boxmsg)
        return connectionState == .loggedIn
    }
    
    func registerMessageListenerDelegate(delegate: MessageListenerDelegate) {
        messageListenerDelegate = delegate
    }

    func unregisterMessageListenerDelegate(delegate: MessageListenerDelegate) {
        if let delegateMsgLis = messageListenerDelegate, delegateMsgLis.isEqual(delegate) {
            messageListenerDelegate = nil
        }
    }

    // MARK: - MessageListenerDelegate

    func messageReceived(listener: MessageListenerDelegate, type: UInt8, data: Data) {
        // no-op
    }

    func registerMessageProcessorDelegate(delegate: MessageProcessorDelegate) {
        messageProcessorDelegate = delegate
    }

    func unregisterMessageProcessorDelegate(delegate: MessageProcessorDelegate) {
        if let delegateMsgPro = messageProcessorDelegate, delegateMsgPro.isEqual(delegate) {
            messageProcessorDelegate = nil
        }
    }

    // MARK: - MessageProcessorDelegate
    
    func beforeDecode() { }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        // no-op
    }
    
    func incomingMessageStarted(_ message: AbstractMessage) { }
    
    func incomingMessageChanged(_ message: AbstractMessage, baseMessage: BaseMessage) { }

    func incomingMessageFinished(_ message: AbstractMessage) { }

    func readMessage(inConversations: Set<ConversationEntity>?) {
        // no-op
    }
    
    func incomingMessageFailed(_ message: BoxedMessage) {
        // no-op
    }

    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        // no-op
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        // no-op
    }

    func taskQueueEmpty() {
        messageProcessorDelegate?.taskQueueEmpty()
    }
    
    func chatQueueDry() { }
    
    func reflectionQueueDry() { }
        
    func processTypingIndicator(_ message: TypingIndicatorMessage) { }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: @escaping (any MessageProcessorDelegate) -> Void,
        onError: @escaping (any Error) -> Void
    ) {
        // no-op
    }
}
