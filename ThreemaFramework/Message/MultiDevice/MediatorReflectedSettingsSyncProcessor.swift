import Foundation
import PromiseKit
import ThreemaProtocols

class MediatorReflectedSettingsSyncProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(settingsSync: D2d_SettingsSync) -> Promise<Void> {
        let syncSettings = settingsSync.update.settings

        frameworkInjector.settingsStoreInternal.updateSettingsStore(with: syncSettings)

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
            object: nil
        )

        return Promise()
    }
}
