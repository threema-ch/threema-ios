//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import SwiftProtobuf
import ThreemaProtocols

class MediatorMessageProcessor: NSObject {
    
    enum MediatorMessageError: Error {
        case noMediatorMessage
        case undefinedType
    }

    private let deviceGroupKeys: DeviceGroupKeys
    private let deviceID: Data
    private let maxBytesToDecrypt: Int
    private let timeoutDownloadThumbnail: Int
    private let mediatorMessageProtocol: MediatorMessageProtocolProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol
    private let socketProtocolDelegate: SocketProtocolDelegate
    private let messageProcessorDelegate: MessageProcessorDelegate

    @objc required init(
        deviceGroupKeys: DeviceGroupKeys,
        deviceID: Data,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int,
        mediatorMessageProtocol: AnyObject,
        userSettings: UserSettingsProtocol,
        taskManager: AnyObject,
        socketProtocolDelegate: SocketProtocolDelegate,
        messageProcessorDelegate: MessageProcessorDelegate
    ) {
        assert(mediatorMessageProtocol is MediatorMessageProtocolProtocol)
        assert(taskManager is TaskManagerProtocol)
        
        self.deviceGroupKeys = deviceGroupKeys
        self.deviceID = deviceID
        self.maxBytesToDecrypt = maxBytesToDecrypt
        self.timeoutDownloadThumbnail = timeoutDownloadThumbnail
        self.userSettings = userSettings
        self.taskManager = taskManager as! TaskManagerProtocol
        self.mediatorMessageProtocol = mediatorMessageProtocol as! MediatorMessageProtocolProtocol
        self.socketProtocolDelegate = socketProtocolDelegate
        self.messageProcessorDelegate = messageProcessorDelegate
    }
    
    /// Decode/decrypt and process all message types from mediator server.
    /// - Parameters:
    ///     - message: Mediator message
    ///     - messageType: Message type, inout parameter objc style
    ///     - receivedAfterInitialQueueSend: True indicates the message was received before mediator server message
    ///                   queue is dry (abstract message will be marked with this flag, to control in app notification)
    /// - Returns: Response data for mediator server or for further processing to clients
    @objc func process(
        message: Data,
        messageType: UnsafeMutablePointer<UInt8>,
        receivedAfterInitialQueueSend: Bool,
        maxDeviceSlots: UnsafeMutablePointer<NSNumber>?
    ) -> Data? {
        
        if !MediatorMessageProtocol.isMediatorMessage(message) {
            return nil
        }
        
        messageType.pointee = message[0]
        let ofType: MediatorMessageProtocol.MediatorMessageType? = MediatorMessageProtocol
            .MediatorMessageType(rawValue: message[0])
        
        switch ofType {
        case .serverHello:
            if let serverHello = mediatorMessageProtocol.decodeServerHello(message: message) {
                DDLogInfo("Server hello")

                guard serverHello.version >= MediatorMessageProtocol.d2mProtocolVersion.min else {
                    DDLogError("Unsupported d2m protocol version \(serverHello.version)")
                    socketProtocolDelegate
                        .didDisconnect(errorCode: ServerConnectionCloseCode.unsupportedProtocolVersion.rawValue)
                    return nil
                }
                
                if let nonce: Data = NaClCrypto.shared()?.randomBytes(kNaClCryptoNonceSize),
                   let encryptedChallenge = NaClCrypto.shared()?
                   .encryptData(
                       serverHello.challenge,
                       withPublicKey: serverHello.esk,
                       signKey: deviceGroupKeys.dgpk,
                       nonce: nonce
                   ) {
                    
                    var response = Data(nonce)
                    response.append(encryptedChallenge)
                    
                    var clientHello = D2m_ClientHello()
                    clientHello.response = response
                    clientHello.deviceID = deviceID.paddedLittleEndian()
                    clientHello.deviceSlotExpirationPolicy = .persistent
                    clientHello.deviceSlotsExhaustedPolicy = .dropLeastRecent
                    clientHello.expectedDeviceSlotState = userSettings.enableMultiDevice ? .existing : .new
                    clientHello.version = min(
                        MediatorMessageProtocol.d2mProtocolVersion.max,
                        serverHello.version
                    )
                    DDLogInfo("Selected D2M protocol version \(clientHello.version)")

                    var deviceInfo = D2d_DeviceInfo()
                    deviceInfo.label = UIDevice().name
                    deviceInfo.appVersion = "\(AppInfo.appVersion.version ?? "-") (\(AppInfo.appVersion.build ?? "-"))"
                    deviceInfo.platform = .ios
                    deviceInfo.platformDetails = UIDevice.modelName

                    if let data = try? deviceInfo.serializedData(),
                       let encryptedData = mediatorMessageProtocol.encryptByte(data: data, key: deviceGroupKeys.dgdik) {
                        clientHello.encryptedDeviceInfo = encryptedData
                    }

                    DDLogVerbose(String(format: "Device ID: %llx", clientHello.deviceID))

                    if let clientHelloMessage = mediatorMessageProtocol.encodeClientHello(clientHello: clientHello) {
                        return clientHelloMessage
                    }
                }
                else {
                    DDLogError("Mediator encryption of challenge failed")
                }
            }
            
        case .serverInfo:
            DDLogInfo("Server info")

            if !userSettings.enableMultiDevice {
                userSettings.enableMultiDevice = true
                // Ensure that the change is observed by SettingStores
                NotificationCenter.default.post(
                    name: .init(rawValue: kNotificationSettingStoreSynchronization),
                    object: nil
                )
                FeatureMask.updateLocal()
            }

            if let serverInfo = mediatorMessageProtocol.decodeServerInfo(message: message) {
                DDLogVerbose("Server info deserialized, device slots \(serverInfo.maxDeviceSlots)")
                maxDeviceSlots?.initialize(to: serverInfo.maxDeviceSlots as NSNumber)
            }
            
        case .reflectionQueueDry:
            DDLogInfo("Reflection queue dry")
            
            if mediatorMessageProtocol.decodeReflectionQueueDry(message: message) != nil {
                messageProcessorDelegate.reflectionQueueDry()
            }
            
        case .rolePromotedToLeader:
            DDLogNotice("Role promoted to leader")
            
            if mediatorMessageProtocol.decodeRolePromotedToLeader(message: message) != nil {
                DDLogVerbose("Role promoted to leader deserialized")
            }

        case .deviceInfo:
            DDLogInfo("Device info")
            return message
            
        case .dropDeviceAck:
            DDLogInfo("Drop device ack")
            return message
            
        case .lockAck:
            DDLogInfo("Lock ack")
            
        case .unlockAck:
            DDLogInfo("Unlock ack")
            
        case .rejected:
            DDLogInfo("Rejected")
            guard let message = MediatorMessageProtocol.decodeTransactionLocked(message) else {
                DDLogError("Could not decode message")
                break
            }
            return mediatorMessageProtocol.decryptByte(data: message.encryptedScope, key: deviceGroupKeys.dgtsk)
            
        case .ended:
            DDLogInfo("Ended")
            guard let message = MediatorMessageProtocol.decodeTransactionLocked(message) else {
                DDLogError("Could not decode message")
                break
            }
            return mediatorMessageProtocol.decryptByte(data: message.encryptedScope, key: deviceGroupKeys.dgtsk)
            
        case .reflectAck:
            DDLogInfo("Reflect ack")
            
            let (reflectID, reflectedAckAt) = MediatorMessageProtocol.decodeReflectAck(message)

            NotificationCenter.default.post(
                name: TaskManager.mediatorMessageAckObserverName(reflectID: reflectID),
                object: reflectID,
                userInfo: [reflectID: reflectedAckAt]
            )

            return nil
            
        case .reflected:
            DDLogInfo("Reflected")

            // Decode and decrypt incoming reflected message
            let (reflectID, reflectedEnvelopeData, reflectedAt) = MediatorMessageProtocol.decodeReflected(message)
            DDLogNotice("[MSG] Incoming reflected message (reflect ID \(reflectID.hexString))")

            if let reflectedEnvelope = mediatorMessageProtocol.decryptEnvelope(data: reflectedEnvelopeData) {
                // Add task for processing incoming reflected message
                let task = TaskDefinitionReceiveReflectedMessage(
                    reflectID: reflectID,
                    reflectedEnvelope: reflectedEnvelope,
                    reflectedAt: reflectedAt,
                    receivedAfterInitialQueueSend: receivedAfterInitialQueueSend,
                    maxBytesToDecrypt: maxBytesToDecrypt,
                    timeoutDownloadThumbnail: timeoutDownloadThumbnail
                )
                taskManager.add(taskDefinition: task)
            }
            else {
                DDLogError("Envelope could not be decrypted for reflected message (reflect ID: \(reflectID.hexString))")
            }
            
            return nil
            
        // case .reflectedAck:
        // DDLogInfo("Reflected ack")
        // break
        default:
            DDLogWarn("Mediator message would not be processed")
        }
        
        return nil
    }
}
