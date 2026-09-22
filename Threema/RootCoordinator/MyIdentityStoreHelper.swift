import Keychain
import ThreemaFramework

enum MyIdentityStoreHelper {
    static func reloadIdentity(from keychainManager: any KeychainManagerProtocol) throws {
        guard let identity = try? keychainManager.loadIdentity() else {
            assertionFailure("We should never end up here, identity should be set up at this point")
            throw AppLaunchManager.AppLaunchError.myIdentityIsMissing
        }
        
        MyIdentityStore.shared().setupIdentity(identity)
    }
}
