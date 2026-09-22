import ThreemaFramework

// MARK: - LicenseStoreAdapterProtocol

@MainActor
protocol LicenseStoreAdapterProtocol: AnyObject {
    /// Direct access to the underlying license store, e.g. to write the credentials of a license
    /// activation link
    var store: any LicenseStoreProtocol { get }
    
    var licenseUsername: String? { get set }
    var licensePassword: String? { get set }
    var licenseDeviceID: String? { get set }
    var onPremConfigURL: String? { get set }
    var isValid: Bool { get }
    
    func performLicenseCheck() async -> Bool
    func performUpdateWorkInfo()
}

// MARK: - LicenseStoreAdapter

@MainActor
final class LicenseStoreAdapter: LicenseStoreAdapterProtocol {

    var store: any LicenseStoreProtocol {
        LicenseStore.shared()
    }
    
    var licenseUsername: String? {
        get {
            store.licenseUsername
        }
        set {
            store.licenseUsername = newValue
        }
    }
    
    var licensePassword: String? {
        get {
            store.licensePassword
        }
        set {
            store.licensePassword = newValue
        }
    }
    
    var licenseDeviceID: String? {
        get {
            store.licenseDeviceID
        }
        set {
            store.licenseDeviceID = newValue ?? String()
        }
    }
    
    var onPremConfigURL: String? {
        get {
            store.onPremConfigURL
        }
        set {
            store.onPremConfigURL = newValue
        }
    }
    
    var isValid: Bool {
        store.isValid()
    }
    
    func performLicenseCheck() async -> Bool {
        await withCheckedContinuation { continuation in
            store.performLicenseCheck { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func performUpdateWorkInfo() {
        store.performUpdateWorkInfo()
    }
}
