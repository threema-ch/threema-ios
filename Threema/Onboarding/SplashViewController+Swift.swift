import Foundation
import SwiftUI
import ThreemaFramework
import UIKit

extension SplashViewController: SetupAppDelegate {
    func encryptedDataDetected() {
        let window = AppDelegate.shared().window
        let viewC = UIHostingController(rootView: RemoteSecretEncryptedDataView())
        let navC = UINavigationController(rootViewController: viewC)
        window?.rootViewController = navC
    }
    
    func mismatchCancelled() {
        assertionFailure("Should not be reached")
    }
}
