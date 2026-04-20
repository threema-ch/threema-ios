import CocoaLumberjackSwift
import FileUtility
import Foundation
import Keychain

extension MyIdentityStore {
    
    enum MyIdentityStoreError: Error {
        case publicKeyDerivationFailed
    }
    
    @objc public var idColor: UIColor {
        IDColor.forData(Data(identity.utf8))
    }
    
    @objc public var resolvedProfilePicture: UIImage {
        guard
            let profilePicture,
            let imageData = profilePicture["ProfilePicture"] as? Data,
            let image = UIImage(data: imageData)
        else {
            return ProfilePictureGenerator.generateImage(for: .me, color: idColor)
        }
        
        return image
    }
    
    @objc public var resolvedGroupCallProfilePicture: UIImage {
        guard
            let profilePicture,
            let imageData = profilePicture["ProfilePicture"] as? Data,
            let image = UIImage(data: imageData)
        else {
            return ProfilePictureGenerator.generateGroupCallImage(initials: "", color: idColor)
        }
        
        return image
    }
    
    @objc public var isDefaultProfilePicture: Bool {
        guard let profilePicture, let imageData = profilePicture["ProfilePicture"] as? Data,
              UIImage(data: imageData) != nil else {
            return true
        }
        
        return false
    }

    public func destroy() {
        // Delete keychain items
        do {
            try BusinessInjector.ui.keychainManager.deleteIdentity()
        }
        catch {
            DDLogError("Delete my identity from keychain failed: \(error)")
        }
        
        removeIdentityUserDefaults()
        
        UserSettings.shared().pushDecrypt = false
        UserSettings.shared().askedForPushDecryption = false
        UserSettings.shared().safeConfig = nil

        NotificationCenter.default.post(name: Notification.Name(kNotificationDestroyedIdentity), object: nil)
    }
    
    public func removeIdentityUserDefaults() {
        KeychainKeyWrapper().deleteWrappingKey()
        DeviceCookieManager.deleteDeviceCookie()
        
        // Delete / reset user settings
        let userDefaults = AppGroup.userDefaults()

        userDefaults?.removeObject(forKey: "PushFromName")

        let fileUtility = FileUtility.shared!
        if let profilePicturePath = profilePicturePath() {
            fileUtility.deleteIfExists(at: URL(string: profilePicturePath))
        }

        userDefaults?.removeObject(forKey: "ProfilePicture")
        userDefaults?.removeObject(forKey: Constants.wallpaperKey)
        userDefaults?.removeObject(forKey: "LinkedEmail")
        userDefaults?.removeObject(forKey: "LinkEmailPending")
        userDefaults?.removeObject(forKey: "LinkedMobileNo")
        userDefaults?.removeObject(forKey: "LinkMobileNoPending")
        userDefaults?.removeObject(forKey: "LinkMobileNoVerificationId")
        userDefaults?.removeObject(forKey: "LinkMobileNoStartDate")
        userDefaults?.removeObject(forKey: "PrivateIdentityInfoLastUpdate")
        userDefaults?.removeObject(forKey: "LastSentFeatureMask")
        userDefaults?.removeObject(forKey: "RevocationPasswordSetDate")
        userDefaults?.removeObject(forKey: "RevocationPasswordLastCheck")
        userDefaults?.removeObject(forKey: "CreateIDEmail")
        userDefaults?.removeObject(forKey: "CreateIDPhone")
        userDefaults?.removeObject(forKey: "FirstName")
        userDefaults?.removeObject(forKey: "LastName")
        userDefaults?.removeObject(forKey: "CSI")
        userDefaults?.removeObject(forKey: "JobTitle")
        userDefaults?.removeObject(forKey: "Department")
        userDefaults?.removeObject(forKey: "Category")
        userDefaults?.removeObject(forKey: "CompanyName")
        userDefaults?.removeObject(forKey: "DirectoryCategories")
        userDefaults?.removeObject(forKey: "LastWorkUpdateRequestHash")
        userDefaults?.removeObject(forKey: "LastWorkUpdateDate")
        userDefaults?.removeObject(forKey: "MessageDrafts")
        userDefaults?.removeObject(forKey: "PushNotificationEncryptionKey")
        userDefaults?.removeObject(forKey: "MatchToken")

        // Should be already removed in app migration
        userDefaults?.removeObject(forKey: "LastWorkUpdateRequest")

        // Reset app setup state. See `AppSetup` for usage of this key
        userDefaults?.removeObject(forKey: kAppSetupStateKey)

        userDefaults?.synchronize()
    }
    
    public func restoreFromBackup(identity: String, clientKey: Data) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            restore(fromBackup: identity, withSecretKey: clientKey) {
                continuation.resume()
            } onError: { _ in
                continuation.resume(throwing: MyIdentityStoreError.publicKeyDerivationFailed)
            }
        }
    }

    public func setupIdentity(_ myIdentity: MyIdentity) {
        identity = myIdentity.$identity
        publicKey = myIdentity.$publicKey
        clientKey = myIdentity.$clientKey
        serverGroup = myIdentity.$serverGroup
    }
}
