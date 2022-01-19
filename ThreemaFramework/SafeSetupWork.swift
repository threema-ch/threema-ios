//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc public class SafeSetupWork: NSObject {
    
    @objc static let backupEnable: Int = 2<<0
    @objc static let backupDisable: Int = 2<<1
    @objc static let backupForce: Int = 2<<2
    @objc static let restoreEnable: Int = 2<<3
    @objc static let restoreDisable: Int = 2<<4
    @objc static let restoreForce: Int = 2<<5
    @objc static let serverPreset: Int = 2<<6
    @objc static let passwordPreset: Int = 2<<7
    
    var safeBackupStatus: Int = 0
    var safeRestoreStatus: Int = 0

    private let mdmSetup: MDMSetup
    
    @objc init(mdmSetup: MDMSetup) {
        self.mdmSetup = mdmSetup

        super.init()
        
        self.initSafeStatus()
    }
    
    @objc public func isSafeBackupStatusSet(safeState: Int) -> Bool {
        return self.safeBackupStatus & safeState == safeState
    }
    
    @objc public func isSafeRestoreStatusSet(safeState: Int) -> Bool {
        return self.safeRestoreStatus & safeState != 0
    }
    
    private func initSafeStatus() {
        
        if self.mdmSetup.disableBackups() {
            self.safeBackupStatus |= SafeSetupWork.backupDisable
        } else {
            if self.mdmSetup.safeEnable() == nil {
                self.safeBackupStatus |= SafeSetupWork.backupEnable
            } else if !Bool(exactly: self.mdmSetup.safeEnable())! {
                self.safeBackupStatus |= SafeSetupWork.backupDisable
            } else {
                self.safeBackupStatus |= SafeSetupWork.backupForce
                
                if self.mdmSetup.safePassword() != nil {
                    self.safeBackupStatus |= SafeSetupWork.passwordPreset
                }
            }

            if self.mdmSetup.safeServerUrl() != nil {
                self.safeBackupStatus |= SafeSetupWork.serverPreset
            }
        }
        
        if self.mdmSetup.disableBackups() || !self.mdmSetup.safeRestoreEnable() {
            self.safeRestoreStatus |= SafeSetupWork.restoreDisable
        } else {
            if self.mdmSetup.safeRestoreId() == nil || self.mdmSetup.safeRestoreId() == "" {
                self.safeRestoreStatus |= SafeSetupWork.restoreEnable
            } else {
                self.safeRestoreStatus |= SafeSetupWork.restoreForce

                if self.mdmSetup.safePassword() != nil {
                    self.safeRestoreStatus |= SafeSetupWork.passwordPreset
                }
            }

            if self.mdmSetup.safeServerUrl() != nil {
                self.safeRestoreStatus |= SafeSetupWork.serverPreset
            }
        }
        
    }
    
}
