import CocoaLumberjackSwift
import Foundation
import GroupCalls
import PromiseKit
import RemoteSecretProtocol

// MARK: - Enums

public enum ContentType: String {
    case json = "application/json"
    case octetStream = "application/octet-stream"
    case multiPart = "multipart/form-data; boundary=---------------------------Boundary_Line"
}

public enum HTTPMethod: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case connect = "CONNECT"
    case options = "OPTIONS"
    case trace = "TRACE"
    case patch = "PATCH"
}

public enum HTTPHeaderField: String {
    case accept = "Accept"
    case contentType = "Content-Type"
    case userAgent = "User-Agent"
    case authorization = "Authorization"
}

public final class HTTPClient: NSObject {
    // MARK: - Properties

    fileprivate var user: String?
    fileprivate var password: String?
    private let authorization: String?
    private let urlSessionManager: URLSessionManager
    fileprivate let sslCAHelper: SSLCAHelperProtocol

    // MARK: - Lifecycle

    override public convenience init() {
        self.init(sessionManager: .shared)
    }

    required init(
        authorization: String?,
        user: String?,
        password: String?,
        sessionManager: URLSessionManager,
        sslCAHelper: SSLCAHelperProtocol
    ) {
        if let user, let password {
            self.user = user
            self.password = password
        }
        self.authorization = authorization
        self.urlSessionManager = sessionManager
        self.sslCAHelper = sslCAHelper
        super.init()
    }

    public convenience init(sessionManager: URLSessionManager = .shared) {
        self.init(
            authorization: nil,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: SSLCAHelper()
        )
    }
    
    /// Initialize HttpClient with Basic Authentication
    /// - Parameters:
    ///   - user: Username for Basic Authentication
    ///   - password: Password for Basic Authentication
    public convenience init(user: String?, password: String?) {
        self.init(
            authorization: nil,
            user: user,
            password: password,
            sessionManager: .shared,
            sslCAHelper: SSLCAHelper()
        )
    }
    
    /// Initialize HttpClient with Authorization header
    /// - Parameter authorization: Authorization header value
    public convenience init(authorization: String?, sessionManager: URLSessionManager = .shared) {
        self.init(
            authorization: authorization,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: SSLCAHelper()
        )
    }

    // MARK: - Delete

    public func delete(url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let request = urlRequest(for: url, httpMethod: .delete, authorization: authorization)
        let task = urlSessionManager.storedSession(for: self, createAsBackgroundSession: false)
            .dataTask(with: request) { data, response, error in
                self.recoveryOnPremIsNeeded(error)
                completionHandler(data, response, error)
            }
        task.resume()
    }
    
    // MARK: - Download

    @discardableResult
    public func downloadData(
        url: URL,
        contentType: ContentType,
        timeout: TimeInterval? = nil,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var request = urlRequest(for: url, httpMethod: .get, authorization: authorization)
        request.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeaderField.accept.rawValue)
        if let timeout {
            request.timeoutInterval = timeout != 0 ? timeout : 60
        }

        let task = urlSessionManager.storedSession(for: self, createAsBackgroundSession: false)
            .dataTask(with: request) { data, response, error in
                self.recoveryOnPremIsNeeded(error)
                completionHandler(data, response, error)
            }
        task.resume()
        
        return task
    }

    public func downloadData(url: URL, contentType: ContentType) async throws -> (Data, URLResponse) {
        var request = urlRequest(for: url, httpMethod: .get, authorization: authorization)
        request.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeaderField.accept.rawValue)

        do {
            return try await urlSessionManager.storedSession(for: self, createAsBackgroundSession: false)
                .data(for: request)
        }
        catch {
            recoveryOnPremIsNeeded(error)
            throw error
        }
    }

    #if DEBUG
        /// Only used for testing.
        public func downloadData(url: URL, delegate: URLSessionDelegate) {
            var request = urlRequest(for: url, httpMethod: .get, authorization: authorization)
            request.setValue(ContentType.octetStream.rawValue, forHTTPHeaderField: HTTPHeaderField.accept.rawValue)

            let task = urlSessionManager.storedSession(for: delegate, createAsBackgroundSession: true)
                .dataTask(with: request)
            task.resume()
        }
    #endif

    public func sendDone(url: URL) async throws {
        let request = urlRequest(for: url, httpMethod: .post, authorization: authorization)

        // It's just important that there was no error here
        do {
            _ = try await urlSessionManager.storedSession(for: nil, createAsBackgroundSession: false)
                .data(for: request, delegate: self)
        }
        catch {
            recoveryOnPremIsNeeded(error)
            throw error
        }
    }

    // MARK: - Upload

    public func uploadData(
        url: URL,
        data: Data,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void
    ) {
        var request = urlRequest(for: url, httpMethod: .put, authorization: authorization)
        request.setValue(
            ContentType.octetStream.rawValue,
            forHTTPHeaderField: HTTPHeaderField.contentType.rawValue
        )

        let task = urlSessionManager.storedSession(for: self, createAsBackgroundSession: false)
            .uploadTask(
                with: request,
                from: data
            ) { data, response, error in
                self.recoveryOnPremIsNeeded(error)
                completionHandler(data, response, error)
            }
        task.resume()
    }
    
    @discardableResult
    public func uploadData(
        url: URL,
        data: Data,
        contentType: ContentType,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var request = urlRequest(for: url, httpMethod: .post, authorization: authorization)
        request.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)

        var task: URLSessionUploadTask!
        task = urlSessionManager.storedSession(for: self, createAsBackgroundSession: false).uploadTask(
            with: request,
            from: data
        ) { data, response, error in
            self.recoveryOnPremIsNeeded(error)
            completionHandler(data, response, error)
        }
        task.resume()
        return task
    }

    #if DEBUG
        /// Only used for testing.
        public func uploadData(url: URL, file: URL, delegate: URLSessionDelegate) {
            var request = urlRequest(for: url, httpMethod: .put, authorization: authorization)
            request.setValue(
                ContentType.octetStream.rawValue,
                forHTTPHeaderField: HTTPHeaderField.contentType.rawValue
            )

            let task = urlSessionManager.storedSession(for: delegate, createAsBackgroundSession: true)
                .uploadTask(with: request, fromFile: file)
            task.resume()
        }
    #endif

    /// Create upload task, HTTP method is POST.
    ///
    /// - Parameters:
    ///   - taskDescription: User defined value, e.g. for identifier
    ///   - url: URL to request
    ///   - contentType: Multipart content type
    ///   - data: Multipart data to uploading
    ///   - delegate: URLSessionTaskDelegate for progress and SSL cert pinning
    ///   - completionHandler: CompletionHandler of session
    ///
    /// - Returns: Upload task
    @available(*, deprecated, message: "Only use with Old_BlobUploader, but you should use BlobManager instead anyway")
    @discardableResult public func uploadDataMultipart(
        taskDescription: String,
        url: URL,
        contentType: String,
        data: Data,
        delegate: URLSessionTaskDelegate,
        completionHandler: @escaping (URLSessionUploadTask?, Data?, URLResponse?, Error?) -> Swift.Void
    ) -> URLSessionUploadTask {
        
        var request = urlRequest(for: url, httpMethod: .post, authorization: authorization)
        request.setValue(contentType, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)

        var task: URLSessionUploadTask!
        task = urlSessionManager.storedSession(for: delegate, createAsBackgroundSession: false).uploadTask(
            with: request,
            from: data
        ) { data, response, error in
            self.recoveryOnPremIsNeeded(error)
            completionHandler(task, data, response, error)
        }
        task.taskDescription = taskDescription
        task.resume()
        return task
    }
    
    // MARK: - Request
    
    private func urlRequest(
        for url: URL,
        httpMethod: HTTPMethod,
        authorization requestAuthorization: String?
    ) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 90.0
        )
        request.httpMethod = httpMethod.rawValue
        request.setValue("Threema", forHTTPHeaderField: HTTPHeaderField.userAgent.rawValue)
        
        if let requestAuthorization {
            request.setValue(requestAuthorization, forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        }
        
        return request
    }

    private func recoveryOnPremIsNeeded(_ error: Error?) {
        guard let nsError = error as? NSError, nsError.code == NSURLErrorCancelled else {
            return
        }

        ServerInfoProviderFactory.recoveryOnPrem()
    }

    /// Invalidates and cancels session for a given delegate
    /// - Parameter delegate: URLSessionDelegate of to be canceled session
    public static func invalidateAndCancelSession(for delegate: URLSessionDelegate) {
        URLSessionManager.shared.invalidateAndCancelSession(for: delegate)
    }
}

// MARK: - URLSessionTaskDelegate

extension HTTPClient: URLSessionTaskDelegate {

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Log authentication mode and response data if is possible
        DDLogDebug(
            "HttpClient authentication method: \(String(describing: challenge.protectionSpace.authenticationMethod))"
        )
        if let error = task.error {
            DDLogNotice("HttpClient error: \(error.localizedDescription)")
        }

        // Set credentials depends on authentication mode
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic,
             NSURLAuthenticationMethodHTTPDigest:
            if challenge.previousFailureCount < 7, let user, let password {
                let credential = URLCredential(user: user, password: password, persistence: .forSession)
                return (.useCredential, credential)
            }
            else {
                return (.performDefaultHandling, nil)
            }
        default:
            return (.performDefaultHandling, nil)
        }
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        do {
            return try await sslCAHelper.handle(challenge: challenge)
        }
        catch {
            fatalError("SSLHelper could not handle challenge, because of error: \(error)")
        }
    }
}

// MARK: - GroupCallHTTPClientAdapterProtocol

extension HTTPClient: GroupCallHTTPClientAdapterProtocol {
    public func sendPeek(authorization: String, url: URL, body: Data) async throws -> (Data, URLResponse) {
        var request = urlRequest(for: url, httpMethod: .post, authorization: authorization)
        request.httpBody = body
        
        return try await urlSessionManager.storedSession(for: nil, createAsBackgroundSession: true)
            .data(for: request, delegate: self)
    }
}

// MARK: - RemoteSecretHTTPClientProtocol

extension HTTPClient: RemoteSecretHTTPClientProtocol {
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = urlSessionManager.storedSession(for: nil, createAsBackgroundSession: true)

        do {
            let (data, urlResponse) = try await session.data(for: request, delegate: self)

            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                throw RemoteSecretHTTPClientProtocolError.invalidResponse
            }

            return (data, httpURLResponse)
        }
        catch {
            recoveryOnPremIsNeeded(error)
            throw error
        }
    }
}
