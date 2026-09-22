import RemoteSecret

/// Store setup configuration of steps after the ID is set
final class SetupConfiguration: NSObject {
    let remoteSecretAndKeychain: RemoteSecretAndKeychainObjC
    
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
    
    @objc init(
        remoteSecretAndKeychain: RemoteSecretAndKeychainObjC,
        mdm: MDMSetup
    ) {
        self.remoteSecretAndKeychain = remoteSecretAndKeychain
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
