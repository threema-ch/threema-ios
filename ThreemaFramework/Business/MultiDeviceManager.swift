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

import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials

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
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let entityManager: EntityManager

    required init(
        serverConnector: ServerConnectorProtocol,
        contactStore: ContactStoreProtocol,
        userSettings: UserSettingsProtocol,
        entityManager: EntityManager
    ) {
        self.serverConnector = serverConnector
        self.contactStore = contactStore
        self.userSettings = userSettings
        self.entityManager = entityManager
    }

    public convenience init() {
        self.init(
            serverConnector: ServerConnector.shared(),
            contactStore: ContactStore.shared(),
            userSettings: UserSettings.shared(),
            entityManager: EntityManager()
        )
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
                    DDLogNotice("Drop other devices")
                    return self.drop(devices: otherDevices)
                }
                .then { () -> Promise<Void> in
                    DDLogNotice("Drop this device")
                    return self.drop(device: self.thisDevice)
                }
                .then { () -> Promise<Void> in
                    DDLogNotice("Deactivate multi device")
                    self.serverConnector.deactivateMultiDevice()
                                                            
                    return Promise()
                }
                .done {
                    continuation.resume()
                }
                .catch { error in
                    DDLogWarn("Disable multi device failed: \(error)")
                    continuation.resume(throwing: error)
                }
        }
        
        // TODO: (SE-199) Remove everything below
        
        do {
            DDLogNotice("Update own feature mask")

            try await FeatureMask.updateLocal()
            
            DDLogNotice("Contact status update start")
            
            let updateTask: Task<Void, Error> = Task {
                try await contactStore.updateStatusForAllContacts(ignoreInterval: true)
            }
            
            // The request time out is 30s thus we wait for 40s for it to complete
            switch try await Task.timeout(updateTask, 40) {
            case .result:
                break
            case let .error(error):
                DDLogError("Contact status update error: \(error ?? "nil")")
            case .timeout:
                DDLogWarn("Contact status update time out")
            }
        }
        catch {
            // We should still try the next steps if this fails and don't report this error back to the caller
            DDLogWarn("Feature mask or contact status update error: \(error)")
        }
        
        // Run refresh steps for all solicitedContactIdentities.
        // (See _Application Update Steps_ in the Threema Protocols for details.)
        
        DDLogNotice("Fetch solicited contacts")
        let solicitedContactIdentities = await entityManager.perform {
            self.entityManager.entityFetcher.allSolicitedContactIdentities()
        }
        
        await ForwardSecurityRefreshSteps().run(for: solicitedContactIdentities.map {
            ThreemaIdentity($0)
        })
    }
}
