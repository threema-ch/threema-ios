import Foundation

/// A protocol defining the interface for fetching work data from the API.
///
/// Conforming types are responsible for making network requests to retrieve
/// work-related data for a list of contacts.
public protocol WorkDataAPICallerProtocol {
    
    /// Fetches work data for the specified contacts.
    ///
    /// - Parameter contacts: An array of contact identifiers to fetch work data for.
    /// - Returns: The raw `Data` response from the API containing work data.
    /// - Throws: An error if the network request fails or the response is invalid.
    func fetchWorkData(with contacts: [String]) async throws -> Data
}
