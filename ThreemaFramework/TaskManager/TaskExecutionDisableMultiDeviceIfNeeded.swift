import CocoaLumberjackSwift
import PromiseKit

final class TaskExecutionDisableMultiDeviceIfNeeded: TaskExecution, TaskExecutionProtocol {
    // This is best-effort and will always succeed even if a legit disabling fails
    func execute() -> Promise<Void> {
        Promise { seal in
            Task {
                guard frameworkInjector.settingsStore.isMultiDeviceRegistered else {
                    // Nothing to-do if multi-device is already disabled
                    seal.fulfill_()
                    return
                }
                
                // Check if any other device is in the group
                
                guard let otherDevices = try? await frameworkInjector.multiDeviceManager.sortedOtherDevices() else {
                    seal.fulfill_()
                    return
                }
                
                guard otherDevices.isEmpty else {
                    seal.fulfill_()
                    return
                }
                
                // No other device in group. Disable multi-device...
                
                do {
                    try await frameworkInjector.multiDeviceManager.disableMultiDevice()
                }
                catch {
                    DDLogError("Failed to automatically disable multi-device: \(error)")
                    seal.fulfill_()
                    return
                }
                
                DDLogNotice("Automatically disabled multi-device")
                seal.fulfill_()
            }
        }
    }
}
