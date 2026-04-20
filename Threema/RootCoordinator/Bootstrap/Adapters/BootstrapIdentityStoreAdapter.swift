import ThreemaFramework

// MARK: - BootstrapIdentityStoreProtocol

@MainActor
protocol BootstrapIdentityStoreProtocol: AnyObject {
    var store: MyIdentityStore { get }
    var identity: String? { get }
    var isValidIdentity: Bool { get }
    var pushFromName: String? { get set }
    var linkedEmail: String? { get }
    var linkedMobileNo: String? { get }
}

// MARK: - BootstrapIdentityStoreAdapter

@MainActor
final class BootstrapIdentityStoreAdapter: BootstrapIdentityStoreProtocol {
    
    var store: MyIdentityStore {
        MyIdentityStore.shared()
    }
    
    var identity: String? {
        store.identity
    }
    
    var isValidIdentity: Bool {
        store.isValidIdentity
    }
    
    var pushFromName: String? {
        get {
            store.pushFromName
        }
        set {
            store.pushFromName = newValue
        }
    }
    
    var linkedEmail: String? {
        store.linkedEmail
    }
    
    var linkedMobileNo: String? {
        store.linkedMobileNo
    }
}
