//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import libthreemaSwift
import RemoteSecretProtocol
import ThreemaEssentials

final class RemoteSecretCreate: RemoteSecretCreateProtocol {
    
    private let appInfo: AppInfo
    private let maxNumberOfRetries: Int
    private let retryWaitInterval: TimeInterval
    private let createTaskResolver: any RemoteSecretCreateTaskResolver
    private let httpClient: any RemoteSecretHTTPClientProtocol
    
    private var retries = 0
    
    // MARK: - Lifecycle
        
    init(
        appInfo: AppInfo,
        maxNumberOfRetries: Int = 5,
        retryWaitInterval: TimeInterval = 10,
        createTaskResolver: any RemoteSecretCreateTaskResolver = DefaultRemoteSecretCreateTaskResolver(),
        httpClient: any RemoteSecretHTTPClientProtocol
    ) {
        self.appInfo = appInfo
        self.maxNumberOfRetries = maxNumberOfRetries
        self.retryWaitInterval = retryWaitInterval
        self.createTaskResolver = createTaskResolver
        self.httpClient = httpClient
    }
    
    // MARK: - RemoteSecretCreateProtocol implementation
    
    func run(
        workServerBaseURL: String,
        licenseUsername: String,
        licensePassword: String,
        identity: ThreemaIdentity,
        clientKey: Data
    ) async throws -> (authenticationToken: Data, identityHash: Data) {
        
        let remoteSecretSetupContext = RemoteSecretSetupContext(
            clientInfo: appInfo.asClientInfo(),
            // swiftformat:disable:next acronyms
            workServerBaseUrl: workServerBaseURL,
            workContext: WorkContext(
                credentials: WorkCredentials(username: licenseUsername, password: licensePassword),
                flavor: .onPrem
            ),
            userIdentity: identity.rawValue,
            clientKey: clientKey
        )
        
        // Run task
        retries = 0
        let (
            remoteSecretAuthenticationToken,
            remoteSecretHash
        ) = try await runRemoteSecretCreateTaskAndHandleError(remoteSecretSetupContext)
        
        // The remote secret exists at this point
        DDLogInfo("Remote secret created")
        
        do {
            let remoteSecretIdentityHash = try deriveRemoteSecretHashForIdentity(
                remoteSecretHash: remoteSecretHash,
                userIdentity: identity.rawValue
            )
            return (remoteSecretAuthenticationToken, remoteSecretIdentityHash)
        }
        catch let RemoteSecretSetupError.InvalidParameter(message: message) {
            DDLogError("RSHID creation failed with invalid parameters: \(message)")
            throw RemoteSecretManagerError.invalidParameter
        }
        catch {
            DDLogError("Unexpected error from libthreema: \(error)")
            throw RemoteSecretManagerError.unknown
        }
    }
    
    // MARK: - Private Helper
    
    private func runRemoteSecretCreateTaskAndHandleError(
        _ context: RemoteSecretSetupContext
    ) async throws -> (remoteSecretAuthenticationToken: Data, remoteSecretHash: Data) {
        // We should retry until we have a result or an error is thrown
        // The while loop prevents recursive calling of this function
        while true {
            do {
                return try await runRemoteSecretCreateTask(context)
            }
            catch let RemoteSecretSetupError.InvalidParameter(message: message) {
                DDLogError("Remote secret creation failed with invalid parameters: \(message)")
                // Here it doesn't make sense to retry after 10s
                throw RemoteSecretManagerError.invalidParameter
            }
            catch let RemoteSecretSetupError.InvalidState(message: message) {
                DDLogError("Remote secret creation failed with an invalid state: \(message)")
                try await waitAndRetryIfNeeded(error: .invalidState)
                // The while loop will try to run it again if it didn't throw...
            }
            catch let RemoteSecretSetupError.NetworkError(message: message) {
                DDLogError("Remote secret creation failed with a network error: \(message)")
                try await waitAndRetryIfNeeded(error: .networkError)
                // The while loop will try to run it again if it didn't throw...
            }
            catch let RemoteSecretSetupError.ServerError(message: message) {
                DDLogError("Remote secret creation failed with a server error: \(message)")
                try await waitAndRetryIfNeeded(error: .serverError)
                // The while loop will try to run it again if it didn't throw...
            }
            catch let RemoteSecretSetupError.InvalidCredentials(message: message) {
                DDLogError("Remote secret creation failed with invalid credentials: \(message)")
                throw RemoteSecretManagerError.invalidCredentials
            }
            catch let RemoteSecretSetupError.RateLimitExceeded(message: message) {
                DDLogError("Remote secret creation failed because of an exceeded rate limit: \(message)")
                try await waitAndRetryIfNeeded(error: .exceededRateLimit)
                // The while loop will try to run it again if it didn't throw...
            }
            catch {
                DDLogError("Remote secret creation failed with an unexpected error from libthreema: \(error)")
                throw RemoteSecretManagerError.unknown
            }
        }
    }
    
    private func waitAndRetryIfNeeded(error: RemoteSecretManagerError) async throws {
        guard retries < maxNumberOfRetries else {
            throw error
        }
        
        retries += 1
        try await Task.sleep(seconds: retryWaitInterval)
    }
    
    private func runRemoteSecretCreateTask(
        _ context: RemoteSecretSetupContext
    ) async throws -> (remoteSecretAuthenticationToken: Data, remoteSecretHash: Data) {
        let remoteSecretCreateTask = try createTaskResolver.createNewTask(with: context)
        
        while true {
            switch try remoteSecretCreateTask.poll() {
            case let .instruction(httpsRequest):
                // If we receive an instruction with a request, we execute it, handle its response or error and poll
                // again...
                let response = await RemoteSecretHelper.runHTTPSRequest(httpsRequest, httpClient: httpClient)
                try remoteSecretCreateTask.response(response: response)

            case let .done(remoteSecretCreateResult):
                let remoteSecretAuthenticationToken = remoteSecretCreateResult.remoteSecretAuthenticationToken
                let remoteSecretHash = remoteSecretCreateResult.remoteSecretHash
                
                // We don't need the remote secret here as we will get it again when we start the monitoring immediately
                // after creation
                assert(
                    remoteSecretCreateResult.remoteSecret.count == 32,
                    "The remote secret should exist at this point"
                )
                
                // We won't zeroize remote secret here as this is only run during the creation of remote secret (LIB-76)
                
                return (remoteSecretAuthenticationToken, remoteSecretHash)
            }
        }
    }
}
