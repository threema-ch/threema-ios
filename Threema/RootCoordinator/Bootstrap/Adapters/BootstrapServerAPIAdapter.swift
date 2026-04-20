import Foundation
import ThreemaFramework

// MARK: - BootstrapServerAPIProtocol

@MainActor
protocol BootstrapServerAPIProtocol: AnyObject {
    /// The underlying ServerAPIConnector instance for direct use when needed.
    var serverAPIConnector: ServerAPIConnector { get }
    
    /// Links an email address to the identity.
    /// - Parameters:
    ///   - email: The email address to link
    /// - Returns: True if already linked, false if verification email was sent
    /// - Throws: Error if linking fails
    func linkEmail(_ email: String) async throws -> Bool
    
    /// Links a mobile number to the identity.
    /// - Parameters:
    ///   - mobileNo: The normalized mobile number in E.164 format
    /// - Returns: True if linking succeeded
    /// - Throws: Error if linking fails
    func linkMobileNo(_ mobileNo: String) async throws -> Bool
}

// MARK: - BootstrapServerAPIAdapter

@MainActor
final class BootstrapServerAPIAdapter: BootstrapServerAPIProtocol {
    
    enum Error: Swift.Error {
        case emailLinkingFailed
        case mobileNumberLinkingFailed
    }
    
    private let identityStore: BootstrapIdentityStoreProtocol
    
    /// The underlying ServerAPIConnector instance.
    let serverAPIConnector: ServerAPIConnector
    
    init(identityStore: BootstrapIdentityStoreProtocol) {
        self.identityStore = identityStore
        self.serverAPIConnector = ServerAPIConnector()
    }
    
    func linkEmail(_ email: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            serverAPIConnector.linkEmail(
                with: identityStore.store,
                email: email,
                onCompletion: { linked in
                    continuation.resume(returning: linked)
                },
                onError: { error in
                    continuation.resume(
                        throwing: error ?? Error.emailLinkingFailed
                    )
                }
            )
        }
    }
    
    func linkMobileNo(_ mobileNo: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            serverAPIConnector.linkMobileNo(
                with: identityStore.store,
                mobileNo: mobileNo,
                onCompletion: { linked in
                    continuation.resume(returning: linked)
                },
                onError: { error in
                    continuation.resume(
                        throwing: error ?? Error.mobileNumberLinkingFailed
                    )
                }
            )
        }
    }
}
