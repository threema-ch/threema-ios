import CocoaLumberjackSwift
import Foundation
import TipKit

public enum TipKitManager {
 
    // MARK: - Lifecycle

    public static func configureTips() {
        do {
            // Check for reset
            if UserSettings.shared().resetTipKitOnNextLaunch {
                try Tips.resetDatastore()
                UserSettings.shared().resetTipKitOnNextLaunch = false
            }
            
            try Tips.configure()
        }
        catch {
            DDLogWarn("Could not configure TipKitManager")
        }
    }
}
