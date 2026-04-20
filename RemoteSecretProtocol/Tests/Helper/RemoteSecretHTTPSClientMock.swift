import Foundation
import RemoteSecretProtocol

public struct RemoteSecretHTTPSClientMock: RemoteSecretHTTPClientProtocol {
    
    public init() { }
    
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (
            Data(),
            HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
