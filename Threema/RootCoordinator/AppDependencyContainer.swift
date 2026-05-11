import Keychain
import RemoteSecretProtocol
import ThreemaFramework

/// Holds the dependencies needed once the app is fully ready (post-RemoteSecret,
/// post-migration). Created by `RootCoordinator` and passed to `AppCoordinator`.
@MainActor
struct AppDependencyContainer {
    let businessInjector: BusinessInjectorProtocol
    let remoteSecretManager: any RemoteSecretManagerProtocol
    let keychainManager: any KeychainManagerProtocol
    let bootstrap: BootstrapContainer
    let wcSessionManager: WCSessionManagerProtocol
}
