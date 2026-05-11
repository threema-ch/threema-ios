import Foundation
@testable import ThreemaFramework

/// A mock implementation of `WorkFetcherContactAdderProtocol` for testing purposes.
///
/// This mock allows tests to verify that contact batch operations are called correctly
/// and captures the contacts being added for verification.
final class WorkFetcherContactStoreMock: WorkFetcherContactAdderProtocol {
    
    // MARK: - Configuration
    
    /// Whether to throw an error when `batchAddWorkContacts` is called.
    var shouldThrowError: Error?
    
    // MARK: - Captured Values
    
    /// The number of times `batchAddWorkContacts` was called.
    private(set) var batchAddWorkContactsCallCount = 0
    
    /// The contacts from the last `batchAddWorkContacts` call.
    private(set) var capturedBatchContacts: [BatchAddWorkContact]?
    
    // MARK: - WorkFetcherContactAdderProtocol
    
    func batchAddWorkContacts(batchAddContacts: [BatchAddWorkContact], lastFullSyncAt: UInt64?) async throws {
        batchAddWorkContactsCallCount += 1
        capturedBatchContacts = batchAddContacts
        
        if let error = shouldThrowError {
            throw error
        }
    }
}
