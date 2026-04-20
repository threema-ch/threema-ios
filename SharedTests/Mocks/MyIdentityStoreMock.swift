import Foundation
import ThreemaFramework
import ThreemaMacros

final class MyIdentityStoreMock: NSObject, MyIdentityStoreProtocol {
    var companyName: String?
    
    var directoryCategories: NSMutableDictionary?
    
    var department: String?
    
    var jobTitle: String?

    var csi: String?

    var category: String?

    var firstName: String?

    var lastName: String?

    var isDefaultProfilePicture: Bool
    
    func displayName() -> String {
        if let name = ContactUtil.name(fromFirstname: firstName, lastname: lastName) {
            return name as String
        }

        if let pushFromName, !pushFromName.isEmpty, pushFromName != identity {
            return pushFromName
        }

        return "\(identity) (\(#localize("me")))"
    }

    var pushFromName: String?

    var linkEmailPending = false

    var createIDEmail: String?
   
    var linkedEmail: String?

    var linkMobileNoPending = false

    var createIDPhone: String?
    
    var linkedMobileNo: String?

    var profilePicture: NSMutableDictionary?

    func encryptData(_ data: Data, withNonce nonce: Data, publicKey: Data) -> Data? {
        NaClCrypto.shared()?.encryptData(data, withPublicKey: publicKey, signKey: clientKey, nonce: nonce)
    }

    func decryptData(_ data: Data, withNonce nonce: Data, publicKey _publicKey: Data) -> Data? {
        NaClCrypto.shared()?.decryptData(data, withSecretKey: clientKey, signKey: _publicKey, nonce: nonce)
    }

    func sharedSecret(withPublicKey publicKey: Data) -> Data? {
        NaClCrypto.shared().sharedSecret(forPublicKey: publicKey, secretKey: clientKey)
    }
    
    func mySharedSecret() -> Data? {
        NaClCrypto.shared().sharedSecret(forPublicKey: publicKey, secretKey: clientKey)
    }

    var publicKey: Data!
    var clientKey: Data?

    init(identity: String, secretKey: Data) {
        self.identity = identity
        self.publicKey = NaClCrypto.shared().derivePublicKey(fromSecretKey: secretKey)
        self.clientKey = secretKey
        self.resolvedProfilePicture = UIImage(systemName: "person.circle")!
        self.resolvedGroupCallProfilePicture = UIImage(systemName: "person.crop.circle")!
        self.isDefaultProfilePicture = false
    }

    override convenience init() {
        self.init(identity: "TESTERID", secretKey: Data(base64Encoded: "WAXm465d3CNnP1pf84RF0mYRgV/Umqwe/8Hun9ntTdQ=")!)
    }

    var identity: String

    var isValidIdentity: Bool {
        false
    }

    var licenseSupportURL: String? = ""

    var serverGroup: String?

    func backupIdentity(withPassword password: String) -> String? {
        ""
    }

    var revocationPasswordSetDate: Date?

    var revocationPasswordLastCheck: Date?
    
    var resolvedProfilePicture: UIImage
    
    var resolvedGroupCallProfilePicture: UIImage
    
    var idColor: UIColor = .red
}
