//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

/// Get and set the current `AppSetupState`
///
/// Additionally we can keep track if a data file existed when the app was launched
///
/// This depends on `MyIdentityStore.shared()` if no state already exists. We do it this way to get the most recent
/// version of the `MyIdentityStore` singleton and prevent the usage of any stale version. At the same time this allows
/// us to just provide static methods.
public class AppSetup: NSObject {
    
    // MARK: - Public
    
    /// Current `AppSetupState`. If is is not set before it is created with the correct state
    ///
    /// `.complete` should only be set as the last step of the setup!
    @objc public static var state: AppSetupState {
        get {
            currentStateAndSetupIfNeeded()
        }
        set {
            DDLogNotice("Update app setup state: old=\(state) new=\(newValue)")
            
            if !(state.rawValue <= newValue.rawValue || newValue == .notSetup) {
                // TODO: (IOS-4531) There might be an illegal transition if `th_safe_restore_enable` is enabled
                DDLogWarn("Illegal app setup state transition")
                assertionFailure()
            }
            
            if newValue == .complete {
                FileUtility.shared.delete(at: AppSetup.noPreexistingDatabaseFile)
            }
            
            AppGroup.userDefaults().set(newValue.rawValue, forKey: Constants.appSetupStateKey)
        }
    }
    
    /// Is the application setup fully completed?
    @objc public static var isCompleted: Bool {
        hasPreexistingDatabaseFile && state == .complete
    }
    
    // MARK: - Internal
    
    /// Should we skip the animation and directly show the setup wizard for with the existing identity?
    @objc static var shouldDirectlyShowSetupWizard: Bool {
        // For the second one we might be able to skip to the last screen, but there is no time to really test this
        state == .identityAdded || state == .identitySetupComplete
    }
    
    /// Is the identity provisioned, but maybe the setup not completed?
    @objc static var isIdentityProvisioned: Bool {
        state == .identitySetupComplete || state == .complete
    }
    
    // MARK: - Preexisting database file
    
    /// This file is created during a call to `registerIfADatabaseFileExists()` and only deleted if `state` is set to
    /// `.complete`
    private static let noPreexistingDatabaseFile: URL? = FileUtility.shared.appDataDirectory?.appendingPathComponent(
        "APP_SETUP_NOT_COMPLETED" // Named like this for backwards compatibility
    )
    
    /// Create a marker if no database file exist when this is called. The marker can only be removed by completing the
    /// setup with setting`state` to `.complete`
    @objc public static func registerIfADatabaseFileExists() {
        if !FileUtility.shared.isExists(fileURL: noPreexistingDatabaseFile),
           !FileUtility.shared.isExists(fileURL: DatabaseManager.storeURL()) {
            FileUtility.shared.write(
                fileURL: noPreexistingDatabaseFile,
                contents: nil
            )
        }
    }
    
    /// Did a database exist when the app was launched for the first time (& `registerIfADatabaseFileExists()` called)
    /// and no setup was completed in the meantime?
    @objc public static var hasPreexistingDatabaseFile: Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            // We create DB for screenshots. Return true to skip wizard
            return true
        }
        
        return !FileUtility.shared.isExists(fileURL: AppSetup.noPreexistingDatabaseFile)
    }
    
    // MARK: - Private helper
    
    private static func currentStateAndSetupIfNeeded() -> AppSetupState {
        
        // This will return 0 if it was not stored before
        let currentValue = AppGroup.userDefaults().integer(forKey: Constants.appSetupStateKey)
        
        // In general we should have a valid state and not fall back to the `else` case
        if let currentState = AppSetupState(rawValue: currentValue) {
            // This should be safe, because the setting is reset in `MyIdentityStore` if there is no identity during
            // setup.
            return currentState
        }
        else {
            let newState: AppSetupState
            
            // The second is not true if the app was deleted and identity still in the keychain. However we don't have
            // a preexisting database at this time.
            if !hasPreexistingDatabaseFile || !MyIdentityStore.shared().isValidIdentity {
                newState = .notSetup
            }
            else {
                newState = .complete
            }
            
            DDLogNotice("Reset app setup state to \(newState)")
            AppGroup.userDefaults().set(newState.rawValue, forKey: Constants.appSetupStateKey)
            
            return newState
        }
    }
}
