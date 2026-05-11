import Foundation

/// A protocol defining the interface for making API requests to the server.
///
/// This protocol abstracts the network layer, allowing for dependency injection
/// and easier testing of components that depend on server communication.
///
/// ## Overview
///
/// The protocol provides methods for posting JSON data to the Work API.
/// Conforming types handle the actual network communication, while consumers
/// of this protocol can work with a consistent interface regardless of the
/// underlying implementation.
///
/// ## Conforming Types
///
/// - `ServerAPIRequestAdapter`: The default implementation that wraps the
///   Objective-C `ServerAPIRequest` class.
public protocol ServerAPIRequestProtocol {
    
    /// Posts JSON data to the specified Work API path.
    ///
    /// This method sends a POST request with JSON-encoded data to the Work API
    /// and returns the response asynchronously.
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (e.g., "fetch2").
    ///   - data: A dictionary containing the data to be sent as JSON in the request body.
    ///
    /// - Returns: The parsed JSON response as an optional dictionary.
    ///
    /// - Throws: An error if the network request fails or the server returns an error.
    func postJSONToWorkAPI(path: String, data: [String: Any]) async throws -> Any?
}
