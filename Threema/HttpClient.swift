//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

public class HttpClient: NSObject {

    private var authenticationMethod: String?
    fileprivate var user: String?
    fileprivate var password: String?
    
    public enum ContentType {
        case json
        case octetStream
        func propertyValue() -> String {
            switch self {
            case .json:
                return "application/json"
            case .octetStream:
                return "application/octet-stream"
            }
        }
    }
    
    private static let bgSessionsMutationLock: DispatchQueue = DispatchQueue(label: "bgSessionsMutationLock")
    private static var bgSessions: [Int: URLSession] = [Int: URLSession]()
    
    override init() {
        super.init()
        self.authenticationMethod = NSURLAuthenticationMethodDefault
    }
    
    /// Initialize HttpClient
    /// - parameter user: Username for Basic Authentication
    /// - parameter password: Password for Basic Authentication
    init(user: String?, password: String?) {
        if let user = user, let password = password {
            self.authenticationMethod = NSURLAuthenticationMethodHTTPBasic
            self.user = user
            self.password = password
        } else {
            self.authenticationMethod = NSURLAuthenticationMethodDefault
        }
    }
    
    func delete(url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let request = getRequest(url: url, httpMethod: "DELETE")
        let task = getSession(delegate: self, background: false).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }

    func downloadData(url: URL, contentType: ContentType, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> Void {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue(contentType.propertyValue(), forHTTPHeaderField: "Accept")
        
        let task = getSession(delegate: self, background: false).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }

    func downloadData(url: URL, delegate: URLSessionDelegate) -> Void {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let task = getSession(delegate: delegate, background: true).dataTask(with: request)
        task.resume()
    }
    
    func uploadData(url: URL, data: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> Void {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(delegate: self, background: false).uploadTask(with: request, from: data, completionHandler: completionHandler)
        task.resume()
    }
    
    func uploadData(url: URL, file: URL, delegate: URLSessionDelegate) -> Void {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(delegate: delegate, background: true).uploadTask(with: request, fromFile: file)
        task.resume()
    }
    
    private func getRequest(url: URL, httpMethod: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 90.0)
        request.httpMethod = httpMethod
        request.setValue("Threema", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    private func getSession(identifier: Int, delegate: URLSessionDelegate, background: Bool) -> URLSession {
        var bgSession: URLSession? = nil

        HttpClient.bgSessionsMutationLock.sync {
            
            if let session = HttpClient.bgSessions[identifier] {
                bgSession = session
            } else {
                let configuration = background ? URLSessionConfiguration.background(withIdentifier: String(identifier)) : URLSessionConfiguration.ephemeral
                configuration.allowsCellularAccess = true
                configuration.sessionSendsLaunchEvents = true
                configuration.urlCache = nil
                configuration.urlCredentialStorage = nil
                
                let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
                HttpClient.bgSessions[identifier] = session
                
                bgSession = session
            }
            
        }
        
        return bgSession!
    }
        
    private func getSession(delegate: URLSessionDelegate?, background: Bool) -> URLSession {
        if let delegate = delegate {
            let objectHash: Int = delegate.hash
            return getSession(identifier: objectHash, delegate: delegate, background: background)
        }

        URLSession.shared.configuration.allowsCellularAccess = true
        URLSession.shared.configuration.urlCache = nil
        URLSession.shared.configuration.urlCredentialStorage = nil
        if #available(iOS 11.0, *) {
            URLSession.shared.configuration.waitsForConnectivity = true
        }
        return URLSession.shared
    }
}

extension HttpClient: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // log authentication mode and response data if is possible
        ValidationLogger.shared()?.logString("HttpClient authentication method: \(String(describing: challenge.protectionSpace.authenticationMethod))")
        if let error = task.error {
            ValidationLogger.shared()?.logString("HttpClient error: \(error.localizedDescription)")
        }

        // set credentials depends on authentication mode
        switch (challenge.protectionSpace.authenticationMethod) {
        case NSURLAuthenticationMethodHTTPBasic,
             NSURLAuthenticationMethodHTTPDigest:
            if (challenge.previousFailureCount < 7), let user = self.user, let password = self.password {
                let credential = URLCredential(user: user, password: password, persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        SSLCAHelper.session(session, didReceive: challenge, completion: completionHandler)
    }
}
