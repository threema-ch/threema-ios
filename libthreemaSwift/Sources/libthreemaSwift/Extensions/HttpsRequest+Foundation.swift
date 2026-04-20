import CocoaLumberjackSwift
import Foundation

extension HttpsRequest {
    /// Creates an ``URLRequest`` from a ``HttpsRequest``
    public func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: url) else {
            DDLogError("[HttpsRequest] received invalid url")
            throw HttpsError.InvalidRequest("[HttpsRequest] Invalid url")
        }
        
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.string
        
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        request.httpBody = body
        
        return request
    }
}
