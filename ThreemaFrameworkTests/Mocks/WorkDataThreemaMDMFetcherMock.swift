import Foundation
@testable import ThreemaFramework

/// A mock implementation of `WorkDataThreemaMDMFetcherProtocol` for testing purposes.
///
/// This mock allows tests to verify that MDM processing is delegated correctly
/// and captures the data being processed for verification.
final class WorkDataThreemaMDMFetcherMock: WorkDataThreemaMDMFetcherProtocol {
    
    // MARK: - Configuration
    
    /// Whether to throw an error when `processAndApply` is called.
    var shouldThrowProcessAndApplyError: Error?
    
    // MARK: - Captured Values for processAndApply
    
    /// The number of times `processAndApply` was called.
    private(set) var processAndApplyCallCount = 0
    
    /// The data from the last `processAndApply` call.
    private(set) var capturedProcessData: Data?
    
    /// The forceSend value from the last `processAndApply` call.
    private(set) var capturedForceSend: Bool?
    
    // MARK: - WorkDataThreemaMDMFetcherProtocol
    
    func processAndApply(_ data: Data, forceSend: Bool) async throws {
        processAndApplyCallCount += 1
        capturedProcessData = data
        capturedForceSend = forceSend
        
        if let error = shouldThrowProcessAndApplyError {
            throw error
        }
    }
    
    func checkUpdateThreemaMDM(forceSend: Bool) async throws {
        // no-op
    }
}
