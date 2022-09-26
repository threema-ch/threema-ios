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

public protocol MultiDeviceManagerProtocol {
    var thisDevice: DeviceInfo { get }
    func otherDevices() -> Promise<[DeviceInfo]>
    func drop(device: DeviceInfo) -> Promise<Bool>
}

public enum MultiDeviceManagerError: Error {
    case multiDeviceNotActivated
    case dropThisDeviceNotAllowed
}

public class MultiDeviceManager: MultiDeviceManagerProtocol {
    private let serverConnector: ServerConnectorProtocol

    required init(serverConnector: ServerConnectorProtocol) {
        self.serverConnector = serverConnector

        // All then-type handlers to run on a background, "finalizers" like done or ctach runs on main queue
        PromiseKit.conf.Q.map = .global()
        PromiseKit.conf.Q.return = .main
    }

    public convenience init() {
        self.init(serverConnector: ServerConnector.shared())
    }

    /// Get device info from this device.
    /// - Returns: This device info
    public var thisDevice: DeviceInfo {
        DeviceInfo(
            deviceID: NSData(data: serverConnector.deviceID).convertUInt64(),
            label: "\(UIDevice().name) \(AppInfo.appVersion.version ?? "-") (\(AppInfo.appVersion.build ?? "-"))",
            lastLoginAt: Date(),
            badge: nil,
            platform: .ios,
            platformDetails: UIDevice.modelName
        )
    }

    /// Get other linked/paired devices.
    /// - Returns: List of other linked/paired devices
    public func otherDevices() -> Promise<[DeviceInfo]> {
        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupPathKey: serverConnector.deviceGroupPathKey)
        )
        return messageReceiver.requestDevicesInfo()
    }

    /// Drop other linked/paired device.
    /// - Parameter device: Linked/paired device that will dropped
    public func drop(device: DeviceInfo) -> Promise<Bool> {
        guard device.deviceID != NSData(data: serverConnector.deviceID).convertUInt64() else {
            return Promise { seal in seal.reject(MultiDeviceManagerError.dropThisDeviceNotAllowed) }
        }

        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupPathKey: serverConnector.deviceGroupPathKey)
        )
        return messageReceiver.requestDropDevice(device: device)
    }
}
