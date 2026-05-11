import Foundation
@testable import ThreemaFramework

/// A mock implementation of `ServerAPIRequestProtocol` for testing purposes.
///
/// This mock allows tests to control the behavior of server API requests by
/// configuring responses and errors. It also captures request information
/// for verification in tests.
final class ServerAPIRequestMock: ServerAPIRequestProtocol {
    
    // MARK: - Configuration
    
    /// The JSON response to return from `postJSONToWorkAPI`.
    /// Set this to configure a successful response.
    var mockResponse: Any?
    
    /// The error to throw from `postJSONToWorkAPI`.
    /// If set, this takes precedence over `mockResponse`.
    var mockError: Error?
    
    // MARK: - Captured Values
    
    /// The path passed to the last `postJSONToWorkAPI` call.
    private(set) var capturedPath: String?
    
    /// The data passed to the last `postJSONToWorkAPI` call.
    private(set) var capturedData: [String: Any]?
    
    /// The number of times `postJSONToWorkAPI` was called.
    private(set) var postJSONCallCount = 0
    
    // MARK: - ServerAPIRequestProtocol
    
    func postJSONToWorkAPI(path: String, data: [String: Any]) async throws -> Any? {
        postJSONCallCount += 1
        capturedPath = path
        capturedData = data
        
        if let error = mockError {
            throw error
        }
        
        return mockResponse
    }
}
