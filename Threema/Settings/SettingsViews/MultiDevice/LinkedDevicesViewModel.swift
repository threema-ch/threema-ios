//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

/// View model for `LinkedDevicesView`
///
/// - Note: In general this should probably be part of `MultiDeviceManager` and this layer should be removed. It is
///         implement as such to prevent a big change of `LinkedDevicesView` and `MultiDeviceManager`.
@MainActor
class LinkedDevicesViewModel: ObservableObject {
    enum State: Equatable {
        case refreshing
        case error
        case noLinkedDevices
        case linkedDevices(devicesInfo: [DeviceInfo])
    }

    @Published var state: State = .refreshing
    @Published var deviceLimitReached = false
    
    nonisolated let businessInjector = BusinessInjector()
    
    nonisolated func refresh() async {
        do {
            let sortedOtherDevices = try await businessInjector.multiDeviceManager.sortedOtherDevices()
            
            Task { @MainActor in
                if sortedOtherDevices.isEmpty {
                    state = .noLinkedDevices
                    deviceLimitReached = false
                }
                else {
                    state = .linkedDevices(devicesInfo: sortedOtherDevices)
                    
                    if let maximumNumberOfDeviceSlots = businessInjector.multiDeviceManager.maximumNumberOfDeviceSlots,
                       // One of the device slots is used by us. Thus we need to subtract that
                       sortedOtherDevices.count >= (maximumNumberOfDeviceSlots - 1) {
                        deviceLimitReached = true
                    }
                    else {
                        deviceLimitReached = false
                    }
                }
            }
        }
        catch {
            DDLogError("Failed to load device list: \(error)")
            
            Task { @MainActor in
                state = .error
            }
        }
    }
    
    /// Remove passed device
    /// - Parameter device: Device info of device to remove
    func remove(_ device: DeviceInfo) async throws {
        try await businessInjector.multiDeviceManager.drop(device: device)
    }
    
    /// Disable multi-device
    func disableMultiDevice() async throws {
        try await businessInjector.multiDeviceManager.disableMultiDevice()
        deviceLimitReached = false
    }
}
