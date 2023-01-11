//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
@testable import ThreemaFramework

class URLProtocolMock: URLProtocol {
    
    enum URLProtocolMockError: Error {
        case noURL
        case noMockResponse
    }
    
    typealias MockURLResponse = (error: Error?, data: Data?, response: HTTPURLResponse?)
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
        
        guard let ((error, data, response), completion) = URLProtocolMock.mockResponses[url] else {
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
        
        client?.urlProtocolDidFinishLoading(self)
        completion?()
    }

    override func stopLoading() {
        // Required by the superclass.
    }
}
