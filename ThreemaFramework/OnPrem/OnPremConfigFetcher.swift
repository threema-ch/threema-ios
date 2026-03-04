//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import FileUtility
import Foundation
import Keychain

public final class OnPremConfigFetcher: NSObject, OnPremConfigFetcherProtocol {
    private let configURL: URL
    private let username: String
    private let password: String

    private let trustedPublicKeys: [String]
    private let cacheURL: URL
        
    private var currentTask: Task<OnPremConfig, any Error>? = nil
    private var cachedConfig: OnPremConfig?
    
    // We intentionally don't use the HTTPClient here, because the initial fetching happens before the business is
    // ready. At he same time there is no requirement to pin the certificate for this request as the OPPF is validated
    // by its checksum
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        
        // Ephemeral sessions will still store a cache in memory. Setting these to `nil` fully disables caching
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        
        return URLSession(configuration: configuration)
    }()
    
    public init(
        configURL: URL,
        username: String,
        password: String,
        trustedPublicKeys: [String],
        cacheURL: URL
    ) {
        self.configURL = configURL
        self.username = username
        self.password = password
        self.trustedPublicKeys = trustedPublicKeys
        self.cacheURL = cacheURL
    }
    
    public func fetch(completionHandler: @escaping (Swift.Result<OnPremConfig, Error>) -> Void) {
        DDLogVerbose("[Fetch OPPF] New fetch")
        
        // The cache is never reset. Thus we can take this shortcut if the config is already cached
        if let cachedConfig {
            DDLogVerbose("[Fetch OPPF] Getting from cache")
            completionHandler(.success(cachedConfig))
            return
        }
        
        // If a task already runs we wait for the result. If no task exists we create a new one and wait on it
        //
        // Note: This is intentionally not fully race safe if the fetch task should only be run once. We landed on this
        // implementation to keep the code more readable and because multiple request to fetch the OPPF are not too
        // resource intensive. This could be fixed by protecting the access of `currentTask` either by making this class
        // an actor or using some sort of mutex or queue.
        Task {
            let task: Task<OnPremConfig, any Error>
            if let currentTask {
                DDLogVerbose("[Fetch OPPF] Load existing fetch task to wait on it")
                task = currentTask
            }
            else {
                DDLogVerbose("[Fetch OPPF] Create new fetch task")
                let newTask = Task {
                    try await self.fetch()
                }
                self.currentTask = newTask
                
                task = newTask
            }
            
            defer {
                self.currentTask = nil
            }
            
            do {
                let config = try await task.value
                completionHandler(.success(config))
            }
            catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    private func fetch() async throws -> OnPremConfig {
        if let cachedConfig {
            DDLogVerbose("[Fetch OPPF] Getting from cache 2")
            return cachedConfig
        }
        
        DDLogVerbose("[Fetch OPPF] Fetch from server")
        let (oppfData, _) = try await session.data(from: configURL, delegate: self)
        
        guard let oppfString = String(data: oppfData, encoding: .utf8) else {
            throw OnPremConfigError.badInputOppfData
        }
        
        if oppfString == "Unauthorized" {
            throw OnPremConfigError.unauthorized
        }
        let verifier = OnPremConfigVerifier(trustedPublicKeys: trustedPublicKeys)
        let config = try verifier.verify(oppfData: oppfString)
        cachedConfig = config
        
        // TODO: (IOS-5579) Remove last line and reenable full file caching
        // Cache config file
        // FileUtility.shared.write(contents: Data(oppfData.utf8), to: cacheURL)
        OnPremCachedWorkServer.storeURLString(config.work?.url)
        
        return config
    }
}

// MARK: - URLSessionTaskDelegate

extension OnPremConfigFetcher: URLSessionTaskDelegate {
    // This is needed (instead of encoding it in the url) to correctly support passwords with special
    // characters (e.g. #)
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic,
             NSURLAuthenticationMethodHTTPDigest:
            if challenge.previousFailureCount < 7 {
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                return (.useCredential, credential)
            }
            else {
                return (.performDefaultHandling, nil)
            }
        default:
            return (.performDefaultHandling, nil)
        }
    }
}
