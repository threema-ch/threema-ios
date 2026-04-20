import Foundation
import Keychain
import ThreemaFramework

// MARK: - SafeComponentsFactory Protocol

@MainActor
protocol SafeComponentsFactory {
    func createSafeConfigManager(keychainManager: KeychainManagerProtocol) -> SafeConfigManagerProtocol
    func createSafeAPIService() -> SafeApiServiceProtocol
    func createSafeStore(
        safeConfigManager: SafeConfigManagerProtocol,
        serverAPIConnector: ServerAPIConnector,
        groupManager: GroupManagerProtocol,
        myIdentityStore: MyIdentityStoreProtocol
    ) -> SafeStore
}

// MARK: - Live Implementation

@MainActor
final class LiveSafeComponentsFactory: SafeComponentsFactory {
    func createSafeConfigManager(keychainManager: KeychainManagerProtocol) -> SafeConfigManagerProtocol {
        SafeConfigManager(keychainManager: keychainManager)
    }
    
    func createSafeAPIService() -> SafeApiServiceProtocol {
        SafeApiService()
    }
    
    func createSafeStore(
        safeConfigManager: SafeConfigManagerProtocol,
        serverAPIConnector: ServerAPIConnector,
        groupManager: GroupManagerProtocol,
        myIdentityStore: MyIdentityStoreProtocol
    ) -> SafeStore {
        SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: groupManager,
            myIdentityStore: myIdentityStore
        )
    }
}
