import CocoaLumberjackSwift
import Foundation

/// Default implementation that wraps the Objective-C `ServerAPIRequest` class.
///
/// This adapter bridges the callback-based `ServerAPIRequest` API to Swift's
/// async/await concurrency model.
public final class ServerAPIRequestAdapter: ServerAPIRequestProtocol {
    
    public init() { }
    
    public func postJSONToWorkAPI(path: String, data: [String: Any]) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            ServerAPIRequest.postJSON(toWorkAPIPath: path, data: data) { json in
                continuation.resume(returning: json)
            } onError: { error in
                if let error {
                    DDLogError("[ServerAPIRequestAdapter] Error: \(error)")
                    continuation.resume(throwing: error)
                }
                else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
