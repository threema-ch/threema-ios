import Foundation
import PromiseKit
@testable import ThreemaFramework

final class MultiDeviceManagerMock: MultiDeviceManagerProtocol {
    var maximumNumberOfDeviceSlots: Int? {
        nil
    }
    
    var thisDevice: DeviceInfo {
        DeviceInfo(
            deviceID: 0,
            label: "Unit test devie name",
            lastLoginAt: Date(),
            badge: "badge",
            platform: .ios,
            platformDetails: "iOS platform details"
        )
    }
    
    func sortedOtherDevices() async throws -> [ThreemaFramework.DeviceInfo] {
        []
    }

    func otherDevices() -> Promise<[DeviceInfo]> {
        Promise { seal in seal.fulfill([]) }
    }
    
    func drop(device: DeviceInfo) async throws {
        // no-op
    }

    func drop(device: DeviceInfo) -> Promise<Void> {
        Promise()
    }
    
    func disableMultiDevice() async throws {
        // no-op
    }
    
    func disableMultiDeviceIfNeeded() {
        // no-op
    }
}
