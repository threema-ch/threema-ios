import Keychain
import RemoteSecretProtocol

/// Store setup configuration of steps after the ID is set
final class SetupConfiguration: NSObject {
    let remoteSecretManager: any RemoteSecretManagerProtocol
    let keychainManager: any KeychainManagerProtocol
    let businessInjector: any BusinessInjectorProtocol
    
    // Parameters from `SafeViewController`
    @objc var safePassword: String?
    var safeServer: String?
    var safeCustomServer: String?
    var safeServerUsername: String?
    var safeServerPassword: String?
    var safeMaxBackupBytes: NSNumber?
    var safeRetentionDays: NSNumber?
    
    // Parameters from `PickNicknameViewController`
    @objc var nickname: String?
    
    // Parameters from `LinkIDViewController`
    @objc var linkEmail: String?
    @objc var linkPhoneNumber: String?
    
    // Parameters from `SyncContactsViewController`
    @objc var syncContacts = false
    
    // MARK: Lifecycle
    
    init(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        businessInjector: any BusinessInjectorProtocol,
        mdm: MDMSetup
    ) {
        self.remoteSecretManager = remoteSecretManager
        self.keychainManager = keychainManager
        self.businessInjector = businessInjector
        
        super.init()
        
        applyMDMDefaults(mdm)
    }
    
    private func applyMDMDefaults(_ mdm: MDMSetup) {
        // These MDM parameters are user editable thus we set them here once
        
        if mdm.existsMdmKey(MDM_KEY_NICKNAME), let nickname = mdm.nickname() {
            self.nickname = nickname
        }
        
        if mdm.existsMdmKey(MDM_KEY_LINKED_EMAIL), let linkEmail = mdm.linkEmail() {
            self.linkEmail = linkEmail
        }
        
        if mdm.existsMdmKey(MDM_KEY_LINKED_PHONE), let linkPhoneNumber = mdm.linkPhoneNumber() {
            self.linkPhoneNumber = linkPhoneNumber
        }
    }
}
