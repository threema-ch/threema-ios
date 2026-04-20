import Foundation
@testable import ThreemaFramework

final class URLProtocolMock: URLProtocol {
    
    enum URLProtocolMockError: Error {
        case noURL
        case noMockResponse
    }
    
    typealias MockURLResponse = (
        error: Error?,
        data: Data?,
        response: HTTPURLResponse?,
        challenges: [URLAuthenticationChallenge]?
    )
    typealias RequestCompletedCallback = () -> Void
    
    static var requests = [URL: URLRequest]()
    static var mockResponses = [URL: (MockURLResponse, RequestCompletedCallback?)]()
    
    // MARK: - URLProtocol
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLProtocolMockError.noURL)
            return
        }
        
        URLProtocolMock.requests[url] = request
        
        guard let ((error, data, response, challenges), completion) = URLProtocolMock.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: URLProtocolMockError.noMockResponse)
            return
        }

        if let errorStrong = error {
            client?.urlProtocol(self, didFailWithError: errorStrong)
        }
        
        if let responseStrong = response {
            client?.urlProtocol(self, didReceive: responseStrong, cacheStoragePolicy: .notAllowed)
        }
        
        if let dataStrong = data {
            client?.urlProtocol(self, didLoad: dataStrong)
        }

        if let challenges {
            for challenge in challenges {
                client?.urlProtocol(self, didReceive: challenge)
            }
        }

        client?.urlProtocolDidFinishLoading(self)
        completion?()
    }

    override func stopLoading() {
        // Required by the superclass.
    }
}
