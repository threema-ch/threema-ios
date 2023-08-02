//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
    func drop(device: DeviceInfo) -> Promise<Void>
    func disableMultiDevice() async throws
}

public enum MultiDeviceManagerError: Error {
    case multiDeviceNotActivated
}

public class MultiDeviceManager: MultiDeviceManagerProtocol {
    private let serverConnector: ServerConnectorProtocol
    private let userSettings: UserSettingsProtocol

    required init(serverConnector: ServerConnectorProtocol, userSettings: UserSettingsProtocol) {
        self.serverConnector = serverConnector
        self.userSettings = userSettings
    }

    public convenience init() {
        self.init(serverConnector: ServerConnector.shared(), userSettings: UserSettings.shared())
    }

    /// Get device info from this device.
    /// - Returns: This device info
    public var thisDevice: DeviceInfo {
        DeviceInfo(
            deviceID: serverConnector.deviceID != nil ? serverConnector.deviceID!.paddedLittleEndian() : 0,
            label: "\(UIDevice().name)",
            lastLoginAt: Date(),
            badge: nil,
            platform: .ios,
            platformDetails: "\(ThreemaUtility.appAndBuildVersionPretty) • \(UIDevice.modelName) "
        )
    }

    /// Get other linked/paired devices.
    /// - Returns: List of other linked/paired devices
    public func otherDevices() -> Promise<[DeviceInfo]> {
        guard let deviceGroupKeys = serverConnector.deviceGroupKeys, let deviceID = serverConnector.deviceID else {
            return Promise { seal in seal.fulfill([DeviceInfo]()) }
        }

        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            userSettings: userSettings,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys)
        )
        return messageReceiver.requestDevicesInfo(thisDeviceID: deviceID)
    }

    /// Drop other linked/paired device.
    /// - Parameter device: Linked/paired device that will dropped
    public func drop(device: DeviceInfo) -> Promise<Void> {
        guard let deviceGroupKeys = serverConnector.deviceGroupKeys else {
            return Promise()
        }

        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            userSettings: userSettings,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys)
        )
        return messageReceiver.requestDropDevice(device: device)
    }
    
    private func drop(devices: [DeviceInfo]) -> Promise<Void> {
        let drops: [Promise<Void>] = devices.map { deviceInfo in
            self.drop(device: deviceInfo)
        }

        return when(fulfilled: drops)
    }
    
    public func disableMultiDevice() async throws {
        try await withCheckedThrowingContinuation { continuation in
            otherDevices()
                .then { otherDevices -> Promise<Void> in
                    self.drop(devices: otherDevices)
                }
                .then { () -> Promise<Void> in
                    self.drop(device: self.thisDevice)
                }
                .then { () -> Promise<Void> in
                    self.serverConnector.deactivateMultiDevice()
                    
                    FeatureMask.update()
                                        
                    return Promise()
                }
                .done {
                    continuation.resume()
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
        }
    }
}
