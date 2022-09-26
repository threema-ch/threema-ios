//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import PromiseKit

public class HttpClient: NSObject {

    private var authenticationMethod: String?
    fileprivate var user: String?
    fileprivate var password: String?
    private var authorization: String?
    
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
    
    private static let bgSessionsMutationLock = DispatchQueue(label: "bgSessionsMutationLock")
    private static var bgSessions = [Int: URLSession]()
    
    override public init() {
        super.init()
        self.authenticationMethod = NSURLAuthenticationMethodDefault
    }
    
    /// Initialize HttpClient with Basic Authentication
    /// - parameter user: Username for Basic Authentication
    /// - parameter password: Password for Basic Authentication
    public init(user: String?, password: String?) {
        if let user = user, let password = password {
            self.authenticationMethod = NSURLAuthenticationMethodHTTPBasic
            self.user = user
            self.password = password
        }
        else {
            self.authenticationMethod = NSURLAuthenticationMethodDefault
        }
    }
    
    /// Initialize HttpClient with Authorization header
    /// - parameter authorization: Authorization header value
    public init(authorization: String?) {
        self.authorization = authorization
        self.authenticationMethod = NSURLAuthenticationMethodDefault
    }
    
    public func delete(url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let request = getRequest(url: url, httpMethod: "DELETE")
        let task = getSession(
            delegate: authenticationMethod != NSURLAuthenticationMethodHTTPBasic ? nil : self,
            background: false
        ).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }

    public func downloadData(
        url: URL,
        contentType: ContentType,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void
    ) {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue(contentType.propertyValue(), forHTTPHeaderField: "Accept")
        
        let task = getSession(
            delegate: authenticationMethod != NSURLAuthenticationMethodHTTPBasic ? nil : self,
            background: false
        ).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }

    public func downloadData(url: URL, delegate: URLSessionDelegate) {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let task = getSession(delegate: delegate, background: true).dataTask(with: request)
        task.resume()
    }
    
    public func uploadData(
        url: URL,
        data: Data,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void
    ) {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(
            delegate: authenticationMethod != NSURLAuthenticationMethodHTTPBasic ? nil : self,
            background: false
        ).uploadTask(with: request, from: data, completionHandler: completionHandler)
        task.resume()
    }
    
    public func uploadData(url: URL, file: URL, delegate: URLSessionDelegate) {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(delegate: delegate, background: true).uploadTask(with: request, fromFile: file)
        task.resume()
    }
    
    /// Create upload task, HTTP method is POST.
    ///
    /// - Parameter taskDescription: User defined value, e.g. for identifier
    /// - Parameter url: URL to request
    /// - Parameter contentType: Multipart content type
    /// - Parameter data: Multipart data to uploading
    /// - Parameter completionHandler: CompletionHandler of session
    ///
    /// - Returns: Upload task
    @discardableResult public func uploadDataMultipart(
        taskDescription: String,
        url: URL,
        contentType: String,
        data: Data,
        delegate: URLSessionTaskDelegate,
        completionHandler: @escaping (URLSessionUploadTask?, Data?, URLResponse?, Error?) -> Swift.Void
    ) -> URLSessionUploadTask {
        
        var request = getRequest(url: url, httpMethod: "POST")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        var task: URLSessionUploadTask!
        task = getSession(delegate: delegate, background: false).uploadTask(
            with: request,
            from: data,
            completionHandler: { data, response, error in
                completionHandler(task, data, response, error)
            }
        )
        task.taskDescription = taskDescription
        task.resume()
        return task
    }
    
    private func getRequest(url: URL, httpMethod: String) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 90.0
        )
        request.httpMethod = httpMethod
        request.setValue("Threema", forHTTPHeaderField: "User-Agent")
        if let authorization = authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    /// Get session for delegate instance.
    ///
    /// - Returns: Session for delegate
    public static func getSession(_ forDelegate: URLSessionDelegate) -> URLSession? {
        HttpClient.bgSessionsMutationLock.sync {
            let identifier: Int = forDelegate.hash
            return HttpClient.bgSessions[identifier]
        }
    }
    
    /// Get session for delegate (one session per delegate instance)
    ///
    /// - Returns: Session for delegate
    private func getSession(identifier: Int, delegate: URLSessionDelegate, background: Bool) -> URLSession {
        var bgSession: URLSession?

        HttpClient.bgSessionsMutationLock.sync {
            
            if let session = HttpClient.bgSessions[identifier] {
                bgSession = session
            }
            else {
                let configuration = background ? URLSessionConfiguration
                    .background(withIdentifier: String(identifier)) : URLSessionConfiguration.ephemeral
                configuration.allowsCellularAccess = true
                configuration.sessionSendsLaunchEvents = true
                configuration.urlCache = nil
                configuration.urlCredentialStorage = nil
                
                let session = URLSession(
                    configuration: configuration,
                    delegate: delegate,
                    delegateQueue: OperationQueue.current
                )
                HttpClient.bgSessions[identifier] = session
                
                bgSession = session
            }
        }
        
        return bgSession!
    }

    /// Get session, if no delegate instance the shared session will be returned.
    ///
    /// - Returns: Session for delegate or shared session
    private func getSession(delegate: URLSessionDelegate?, background: Bool) -> URLSession {
        if let delegate = delegate {
            let objectHash: Int = delegate.hash
            return getSession(identifier: objectHash, delegate: delegate, background: background)
        }

        URLSession.shared.configuration.allowsCellularAccess = true
        URLSession.shared.configuration.urlCache = nil
        URLSession.shared.configuration.urlCredentialStorage = nil
        URLSession.shared.configuration.waitsForConnectivity = true
        return URLSession.shared
    }
}

// MARK: - URLSessionTaskDelegate

extension HttpClient: URLSessionTaskDelegate {
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        // Log authentication mode and response data if is possible
        DDLogNotice(
            "HttpClient authentication method: \(String(describing: challenge.protectionSpace.authenticationMethod))"
        )
        if let error = task.error {
            DDLogNotice("HttpClient error: \(error.localizedDescription)")
        }

        // Set credentials depends on authentication mode
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic,
             NSURLAuthenticationMethodHTTPDigest:
            if challenge.previousFailureCount < 7, let user = user, let password = password {
                let credential = URLCredential(user: user, password: password, persistence: .forSession)
                completionHandler(.useCredential, credential)
            }
            else {
                completionHandler(.performDefaultHandling, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
         
        SSLCAHelper.session(session, didReceive: challenge, completion: completionHandler)
    }
}
