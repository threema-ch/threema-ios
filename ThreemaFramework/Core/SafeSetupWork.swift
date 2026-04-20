import Foundation

@objc final class SafeSetupWork: NSObject {
    
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
            if let safeEnable = mdmSetup.safeEnable() {
                if let safeEnableBool = Bool(exactly: safeEnable),
                   !safeEnableBool {
                    safeBackupStatus |= SafeSetupWork.backupDisable
                }
                else {
                    safeBackupStatus |= SafeSetupWork.backupForce
                    
                    if mdmSetup.safePassword() != nil {
                        safeBackupStatus |= SafeSetupWork.passwordPreset
                    }
                }
            }
            else {
                safeBackupStatus |= SafeSetupWork.backupEnable
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
