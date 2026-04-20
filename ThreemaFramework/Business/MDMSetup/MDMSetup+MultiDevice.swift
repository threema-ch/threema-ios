import CocoaLumberjackSwift
import Foundation

extension MDMSetup {
    @objc func runDisableMultiDevice() async {
        guard let localBusniessInjector = businessInjector as? BusinessInjector else {
            DDLogError("BusinessInjector is not set")
            return
        }

        guard !ProcessInfoHelper.isRunningForTests else {
            localBusniessInjector.userSettings.enableMultiDevice = false
            return
        }

        guard localBusniessInjector.settingsStore.isMultiDeviceRegistered else {
            return
        }
        
        do {
            try await localBusniessInjector.multiDeviceManager.disableMultiDevice()
        }
        catch {
            DDLogError("Disabling multi-device from MDMSetup failed: \(error)")
        }
    }
}
