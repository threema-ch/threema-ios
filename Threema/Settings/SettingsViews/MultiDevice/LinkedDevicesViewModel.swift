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
    
    let businessInjector = BusinessInjector.ui
    
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
