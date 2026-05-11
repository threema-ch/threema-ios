#if DEBUG

    extension MyIdentityStoreProtocol where Self == MockMyIdentityStore {
        public static var mock: any MyIdentityStoreProtocol {
            let m = MockMyIdentityStore()
            m.identity = "ECHOECHO"
            return m
        }
    }

    public final class MockMyIdentityStore: NSObject, MyIdentityStoreProtocol {
        public var linkMobileNoVerificationID: String?
    
        public var linkMobileNoStartDate: Date?
    
        public var privateIdentityInfoLastUpdate: Date?
    
        public var lastWorkUpdateRequestHash: Data?
    
        public var lastWorkUpdateDate: Date?

        public var identity: String?

        public var pushFromName: String?

        public var createIDEmail: String?

        public var linkEmailPending = false

        public var linkedEmail: String?

        public var createIDPhone: String?

        public var linkMobileNoPending = false

        public var linkedMobileNo: String?

        public var profilePicture: NSMutableDictionary?

        public var publicKey: Data?

        public var clientKey: Data?

        public var firstName: String?

        public var lastName: String?

        public var csi: String?

        public var jobTitle: String?

        public var department: String?

        public var category: String?
        
        public var licenseLogoLightURL: String?
        
        public var licenseLogoDarkURL: String?

        public var resolvedProfilePicture = UIImage.checkmark

        public var resolvedGroupCallProfilePicture = UIImage.checkmark

        public var isDefaultProfilePicture = false

        public var companyName: String?

        public var directoryCategories: NSMutableDictionary?

        public var isValidIdentity = false

        public var revocationPasswordSetDate: Date?

        public var revocationPasswordLastCheck: Date?

        public var licenseSupportURL: String?

        public var serverGroup: String?

        public var idColor: UIColor = .red
    
        override public init() { /* no-op */ }

        public func encryptData(_ data: Data, withNonce nonce: Data, publicKey: Data) -> Data? { nil }

        public func decryptData(_ data: Data, withNonce nonce: Data, publicKey: Data) -> Data? { nil }

        public func sharedSecret(withPublicKey publicKey: Data) -> Data? { nil }

        public func mySharedSecret() -> Data? { nil }

        public func displayName() -> String { "" }

        public func backupIdentity(withPassword password: String) -> String? { nil }
    
        public func sendUpdateWorkInfoStatus() -> Bool { false }
    }

#endif
