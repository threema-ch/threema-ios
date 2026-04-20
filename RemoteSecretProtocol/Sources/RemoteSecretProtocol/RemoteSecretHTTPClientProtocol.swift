import Foundation

public protocol RemoteSecretHTTPClientProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public enum RemoteSecretHTTPClientProtocolError: Error {
    case invalidResponse
}
