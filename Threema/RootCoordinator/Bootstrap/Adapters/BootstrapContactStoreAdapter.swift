import Foundation
import ThreemaFramework

// MARK: - BootstrapContactStoreProtocol

@MainActor
protocol BootstrapContactStoreProtocol: AnyObject {
    /// Synchronizes the address book with forced full sync.
    /// - Parameter forceFullSync: Whether to force a full sync
    /// - Returns: True if address book access was granted
    /// - Throws: Error if synchronization fails
    func synchronizeAddressBook(forceFullSync: Bool) async throws -> Bool
}

// MARK: - BootstrapContactStoreAdapter

@MainActor
final class BootstrapContactStoreAdapter: BootstrapContactStoreProtocol {
    
    enum Error: Swift.Error {
        case addressBookSyncFailed
    }
    
    private var store: ContactStore {
        ContactStore.shared()
    }
    
    func synchronizeAddressBook(forceFullSync: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.synchronizeAddressBook(
                forceFullSync: forceFullSync,
                onCompletion: { addressBookAccessGranted in
                    continuation.resume(returning: addressBookAccessGranted)
                },
                onError: { error in
                    continuation.resume(
                        throwing: error ?? Error.addressBookSyncFailed
                    )
                }
            )
        }
    }
}
