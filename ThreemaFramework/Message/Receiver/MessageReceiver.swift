//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import PromiseKit

enum MessageReceiverError: Error {
    case reflectMessageFailed
    case responseTimeout
    case wrongResponseType
    case encodingFailed
    case decodingFailed
}

final class MessageReceiver {
    private let serverConnector: ServerConnectorProtocol
    private let mediatorMessageProtocol: MediatorMessageProtocolProtocol

    private let responseTimeoutInSeconds = 25

    required init(serverConnector: ServerConnectorProtocol, mediatorMessageProtocol: MediatorMessageProtocolProtocol) {
        self.serverConnector = serverConnector
        self.mediatorMessageProtocol = mediatorMessageProtocol
    }

    /// Send get devices info to Mediator server and get linked/paired devices.
    /// - Returns: Linked/paired other devices
    /// - Throws: MultiDeviceManagerError.multiDeviceNotActivated, MessageReceiverError
    func requestDevicesInfo() -> Promise<[DeviceInfo]> {
        let dispatchMessageListener = DispatchGroup()
        let messageListener = MessageListener(dispatchMessageListener: dispatchMessageListener)

        return firstly {
            Guarantee { $0(serverConnector.isMultiDeviceActivated) }
        }
        .then { (isMultiDeviceActivated: Bool) -> Promise<Data?> in
            guard isMultiDeviceActivated else {
                throw MultiDeviceManagerError.multiDeviceNotActivated
            }

            return Promise { $0.fulfill(self.mediatorMessageProtocol.encodeGetDeviceList()) }
        }
        .then { (getDevicesList: Data?) -> Promise<[DeviceInfo]> in
            guard let getDevicesList = getDevicesList else {
                throw MessageReceiverError.encodingFailed
            }

            dispatchMessageListener.enter()

            self.serverConnector.registerMessageListenerDelegate(delegate: messageListener)

            if !self.serverConnector.reflectMessage(getDevicesList) {
                throw MessageReceiverError.reflectMessageFailed
            }

            let result = dispatchMessageListener.wait(timeout: .now() + .seconds(self.responseTimeoutInSeconds))
            if result != .success {
                throw MessageReceiverError.responseTimeout
            }

            guard let responseType = messageListener.responseType,
                  responseType == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_DEVICE_INFO else {
                throw MessageReceiverError.wrongResponseType
            }

            guard let responseData = messageListener.responseData,
                  let devicesInfo = self.mediatorMessageProtocol.decodeDevicesInfo(message: responseData) else {
                throw MessageReceiverError.decodingFailed
            }

            // Convert multi device protocol objects to business objects
            var devices: [DeviceInfo] = []

            for item in devicesInfo.augmentedDeviceInfo
                .filter({ NSData.convertBytes($0.key).hexString != self.serverConnector.deviceID.hexString }) {
                var label: String!
                var platform: Platform = .unspecified
                var platformDetails = "Unknown"
                if !item.value.encryptedDeviceInfo.isEmpty,
                   let decryptedDeviceInfo = self.mediatorMessageProtocol
                   .decryptByte(data: item.value.encryptedDeviceInfo),
                   let decodedDeviceInfo = self.mediatorMessageProtocol.decodeDeviceInfo(message: decryptedDeviceInfo) {
                    label = "\(decodedDeviceInfo.label) \(decodedDeviceInfo.appVersion)"
                    platform = Platform(rawValue: decodedDeviceInfo.platform.rawValue) ?? .unspecified
                    platformDetails = decodedDeviceInfo.platformDetails
                }
                else {
                    label = "Unknown"
                }

                let badge = item.value.deviceSlotExpirationPolicy == .volatile ? "Volatile Session" : nil
                devices.append(DeviceInfo(
                    deviceID: item.key,
                    label: label,
                    lastLoginAt: Date(milliseconds: Int64(item.value.lastLoginAt)),
                    badge: badge,
                    platform: platform,
                    platformDetails: platformDetails
                ))
            }

            return Promise { $0.fulfill(devices) }
        }
        .ensure {
            self.serverConnector.unregisterMessageListenerDelegate(delegate: messageListener)
        }
    }

    /// Send drop device to Mediator server.
    /// - Parameter device: Linked/paired device that will be dropped
    /// - Throws: MultiDeviceManagerError.multiDeviceNotActivated, MessageReceiverError
    func requestDropDevice(device: DeviceInfo) -> Promise<Bool> {
        let dispatchMessageListener = DispatchGroup()
        let messageListener = MessageListener(dispatchMessageListener: dispatchMessageListener)

        return firstly {
            Guarantee { $0(serverConnector.isMultiDeviceActivated) }
        }
        .then { (isMultiDeviceActivated: Bool) -> Guarantee<Data?> in
            guard isMultiDeviceActivated else {
                throw MultiDeviceManagerError.multiDeviceNotActivated
            }

            return Guarantee { $0(self.mediatorMessageProtocol.encodeDropDevice(deviceID: device.deviceID)) }
        }
        .then { (dropDevice: Data?) -> Promise<Bool> in
            guard let dropDevice = dropDevice else {
                throw MessageReceiverError.encodingFailed
            }

            dispatchMessageListener.enter()

            self.serverConnector.registerMessageListenerDelegate(delegate: messageListener)

            if !self.serverConnector.reflectMessage(dropDevice) {
                throw MessageReceiverError.reflectMessageFailed
            }

            let result = dispatchMessageListener.wait(timeout: .now() + .seconds(self.responseTimeoutInSeconds))
            if result != .success {
                throw MessageReceiverError.responseTimeout
            }

            guard let responseType = messageListener.responseType,
                  responseType == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_DROP_DEVICE_ACK else {
                throw MessageReceiverError.wrongResponseType
            }

            guard let responseData = messageListener.responseData,
                  let dropDeviceAck = self.mediatorMessageProtocol.decodeDropDeviceAck(message: responseData) else {
                throw MessageReceiverError.decodingFailed
            }

            return Promise { seal in seal.fulfill(device.deviceID == dropDeviceAck.deviceID) }
        }
        .ensure {
            self.serverConnector.unregisterMessageListenerDelegate(delegate: messageListener)
        }
    }

    private class MessageListener: NSObject, MessageListenerDelegate {
        private let dispatchMessageListener: DispatchGroup

        required init(dispatchMessageListener: DispatchGroup) {
            self.dispatchMessageListener = dispatchMessageListener
            super.init()
        }

        var responseType: UInt8?
        var responseData: Data?

        func messageReceived(type: UInt8, data: Data) {
            responseType = type
            responseData = data
            dispatchMessageListener.leave()
        }
    }
}
