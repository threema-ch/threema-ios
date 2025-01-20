//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import Foundation

@objc class SafeSetupWork: NSObject {
    
    @objc static let backupEnable = 2 << 0
    @objc static let backupDisable = 2 << 1
    @objc static let backupForce = 2 << 2
    @objc static let restoreEnable = 2 << 3
    @objc static let restoreDisable = 2 << 4
    @objc static let restoreForce = 2 << 5
    @objc static let serverPreset = 2 << 6
    @objc static let passwordPreset = 2 << 7
    
    var safeBackupStatus = 0
    var safeRestoreStatus = 0

    private let mdmSetup: MDMSetup
    
    @objc init(mdmSetup: MDMSetup) {
        self.mdmSetup = mdmSetup

        super.init()
        
        initSafeStatus()
    }
    
    @objc func isSafeBackupStatusSet(safeState: Int) -> Bool {
        safeBackupStatus & safeState == safeState
    }
    
    @objc func isSafeRestoreStatusSet(safeState: Int) -> Bool {
        safeRestoreStatus & safeState != 0
    }
    
    private func initSafeStatus() {
        
        if mdmSetup.disableBackups() {
            safeBackupStatus |= SafeSetupWork.backupDisable
        }
        else {
            if mdmSetup.safeEnable() == nil {
                safeBackupStatus |= SafeSetupWork.backupEnable
            }
            else if !Bool(exactly: mdmSetup.safeEnable())! {
                safeBackupStatus |= SafeSetupWork.backupDisable
            }
            else {
                safeBackupStatus |= SafeSetupWork.backupForce
                
                if mdmSetup.safePassword() != nil {
                    safeBackupStatus |= SafeSetupWork.passwordPreset
                }
            }

            if mdmSetup.safeServerURL() != nil {
                safeBackupStatus |= SafeSetupWork.serverPreset
            }
        }
        
        if mdmSetup.disableBackups() || !mdmSetup.safeRestoreEnable() {
            safeRestoreStatus |= SafeSetupWork.restoreDisable
        }
        else {
            if mdmSetup.safeRestoreID() == nil || mdmSetup.safeRestoreID() == "" {
                safeRestoreStatus |= SafeSetupWork.restoreEnable
            }
            else {
                safeRestoreStatus |= SafeSetupWork.restoreForce

                if mdmSetup.safePassword() != nil {
                    safeRestoreStatus |= SafeSetupWork.passwordPreset
                }
            }

            if mdmSetup.safeServerURL() != nil {
                safeRestoreStatus |= SafeSetupWork.serverPreset
            }
        }
    }
}
