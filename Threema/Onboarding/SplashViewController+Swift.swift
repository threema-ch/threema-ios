import Foundation
import SwiftUI
import ThreemaFramework
import UIKit

extension SplashViewController: SetupAppDelegate {
    func encryptedDataDetected() {
        #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
            /// In the coordinator flow, RS resolution is handled by OnboardingCoordinator
            /// which calls showEncryptedDataDetected() directly. This path is unreachable.
            assertionFailure("encryptedDataDetected should not be called in coordinator flow")
            return
        #else
            let window = AppDelegate.shared().window
            let viewC = UIHostingController(rootView: RemoteSecretEncryptedDataView())
            let navC = UINavigationController(rootViewController: viewC)
            window?.rootViewController = navC
        #endif
    }
    
    func mismatchCancelled() {
        assertionFailure("Should not be reached")
    }
}
