import Foundation

public protocol GroupCallHTTPClientAdapterProtocol {
    func sendPeek(authorization: String, url: URL, body: Data) async throws -> (Data, URLResponse)
}
