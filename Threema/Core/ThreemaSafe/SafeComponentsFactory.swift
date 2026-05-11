import Foundation
import Keychain
import ThreemaFramework

// MARK: - SafeComponentsFactory Protocol

@MainActor
protocol SafeComponentsFactory {
    func createSafeConfigManager(keychainManager: KeychainManagerProtocol) -> SafeConfigManagerProtocol
    func createSafeAPIService() -> SafeApiServiceProtocol
    func createSafeStore(
        safeConfigManager: any SafeConfigManagerProtocol,
        serverAPIConnector: ServerAPIConnector,
        groupManager: any GroupManagerProtocol,
        myIdentityStore: any MyIdentityStoreProtocol,
        phoneNumberNormalizer: any PhoneNumberNormalizerProtocol
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
        safeConfigManager: any SafeConfigManagerProtocol,
        serverAPIConnector: ServerAPIConnector,
        groupManager: any GroupManagerProtocol,
        myIdentityStore: any MyIdentityStoreProtocol,
        phoneNumberNormalizer: any PhoneNumberNormalizerProtocol
    ) -> SafeStore {
        SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: groupManager,
            myIdentityStore: myIdentityStore,
            phoneNumberNormalizer: phoneNumberNormalizer
        )
    }
}
