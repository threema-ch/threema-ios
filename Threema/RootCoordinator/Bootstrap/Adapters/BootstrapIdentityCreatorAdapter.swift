import ThreemaFramework

// MARK: - BootstrapIdentityCreatorProtocol

@MainActor
protocol BootstrapIdentityCreatorProtocol: AnyObject {
    func generateKeyPair(withSeed seed: Data)

    func createIdentity() async -> BootstrapIdentityCreationResult
}

// MARK: - BootstrapIdentityCreationResult

typealias BootstrapIdentityCreationResult = Result<Void, Error>

// MARK: - BootstrapIdentityCreatorAdapter

@MainActor
final class BootstrapIdentityCreatorAdapter: BootstrapIdentityCreatorProtocol {
    
    enum Error: Swift.Error {
        case createIdentityFailed
    }

    private var store: MyIdentityStore {
        MyIdentityStore.shared()
    }

    func generateKeyPair(withSeed seed: Data) {
        store.generateKeyPair(withSeed: seed)
    }

    func createIdentity() async -> BootstrapIdentityCreationResult {
        await withCheckedContinuation { continuation in
            let connector = ServerAPIConnector()
            connector.createIdentity(with: store) { _ in
                continuation.resume(returning: .success(()))
            } onError: { error in
                continuation.resume(
                    returning: .failure(error ?? Error.createIdentityFailed)
                )
            }
        }
    }
}
