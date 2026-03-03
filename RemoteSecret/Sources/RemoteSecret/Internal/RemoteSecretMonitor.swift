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
import Keychain
import libthreemaSwift
import RemoteSecretProtocol
import ThreemaEssentials

/// Handler of remote secret monitoring using libthreema
@MainActor // For now we stick with main actor. If this blocks the UI we should probably switch to `actor`
final class RemoteSecretMonitor: RemoteSecretMonitorSwiftProtocol {
    
    private let appInfo: AppInfo
    private let monitorProtocolResolver: any RemoteSecretMonitorProtocolResolver
    private let httpClient: any RemoteSecretHTTPClientProtocol
    
    private var remoteSecretFetchCompleted = false {
        didSet {
            assert(remoteSecretFetchCompleted, "This should never be reset")
        }
    }

    private var currentRemoteSecretMonitorProtocol: (any RemoteSecretMonitorProtocolProtocol)?
    private var waitTask: Task<Void, any Error>?
    
    // Keep track if the monitor check runs right now. If this is the case we shouldn't enforce a new run.
    // Otherwise stopping the current run (by canceling the task) might leave the libthreema monitor in an intermediate
    // state that leads to an invalid state if we start a new monitor check run from the outside
    private let isMonitorCheckRunning = Atomic(wrappedValue: false)
    
    // MARK: - Lifecycle
        
    /// Create new monitor
    /// - Parameters:
    ///   - appInfo: Info about the current app
    ///   - monitorProtocolResolver: Resolver to pick remote secret monitor protocol implementation
    ///   - httpClient: HTTP client to be used by monitor
    init(
        appInfo: AppInfo,
        monitorProtocolResolver: any RemoteSecretMonitorProtocolResolver = DefaultRemoteSecretMonitorProtocolResolver(),
        httpClient: any RemoteSecretHTTPClientProtocol
    ) {
        self.appInfo = appInfo
        self.monitorProtocolResolver = monitorProtocolResolver
        self.httpClient = httpClient
    }
    
    // MARK: - RemoteSecretMonitorSwiftProtocol implementation
    
    func createAndStart(
        workServerBaseURL: String,
        identity: ThreemaIdentity,
        remoteSecretAuthenticationToken: Data,
        remoteSecretIdentityHash: Data
    ) async throws -> RemoteSecret {
        let remoteSecretMonitorProtocol = try createRemoteSecretMonitorProtocol(
            workServerBaseURL: workServerBaseURL,
            remoteSecretAuthenticationToken: remoteSecretAuthenticationToken,
            identity: identity,
            remoteSecretIdentityHash: remoteSecretIdentityHash
        )
        currentRemoteSecretMonitorProtocol = remoteSecretMonitorProtocol
        
        guard let remoteSecretKey = try await runRemoteSecretMonitorProtocolAndMapError(
            remoteSecretMonitorProtocol,
            httpClient: httpClient
        ) else {
            let message = "Monitor creation lead to a nil remote secret. This should never happen"
            DDLogError("\(message)")
            fatalError(message)
        }
                
        return remoteSecretKey
    }

    func runCheck() async {
        // If the monitor check is running right now we're good
        guard !isMonitorCheckRunning.wrappedValue else {
            return
        }
        
        // If any error occurs it is handled the same way as in the recurring monitor task
        waitTask?.cancel()
        
        guard let currentRemoteSecretMonitorProtocol else {
            fatalError("A monitor should be running at this point")
        }
        
        await runRemoteSecretMonitorProtocolAndHandleError(currentRemoteSecretMonitorProtocol, httpClient: httpClient)
    }
    
    func stop() async {
        waitTask?.cancel()
        waitTask = nil
    }
    
    // MARK: - Private Helper
    
    // MARK: Creation
    
    private func createRemoteSecretMonitorProtocol(
        workServerBaseURL: String,
        remoteSecretAuthenticationToken: Data,
        identity: ThreemaIdentity,
        remoteSecretIdentityHash: Data
    ) throws -> any RemoteSecretMonitorProtocolProtocol {
        do {
            return try monitorProtocolResolver.createProtocol(
                clientInfo: appInfo.asClientInfo(),
                workServerBaseURLString: workServerBaseURL,
                remoteSecretAuthenticationToken: remoteSecretAuthenticationToken,
                remoteSecretVerifier: .remoteSecretHashForIdentity(
                    userIdentity: identity.rawValue,
                    remoteSecretHashForIdentity: remoteSecretIdentityHash
                )
            )
        }
        catch let RemoteSecretMonitorError.InvalidParameter(message: message) {
            DDLogError("Invalid parameter while unlocking: \(message)")
            throw RemoteSecretManagerError.invalidParameter
        }
        catch {
            DDLogError("Unexpected error from libthreema while unlocking: \(error)")
            throw RemoteSecretManagerError.unknown
        }
    }
    
    // MARK: Polling
    
    private func runRemoteSecretMonitorProtocolAndHandleError(
        _ remoteSecretMonitorProtocol: any RemoteSecretMonitorProtocolProtocol,
        httpClient: any RemoteSecretHTTPClientProtocol
    ) async {
        do {
            _ = try await runRemoteSecretMonitorProtocolAndMapError(
                remoteSecretMonitorProtocol,
                httpClient: httpClient
            )
        }
        // When an error is thrown the monitor needs to be restarted before it can be used again. Probably by a user
        // interaction
        catch let error as RemoteSecretManagerError {
            // TODO: (IOS-5542) In the future it might be safe to reset the wonky encryption and switch out the screen/app parts in memory
            let message = "Remote secret monitoring error occurred: \(error.description)"
            DDLogError("\(message)")
            fatalError(message)
        }
        catch {
            let message = "Unexpected remote secret monitoring error occurred: \(error)"
            DDLogError("\(message)")
            fatalError(message)
        }
    }
    
    private func runRemoteSecretMonitorProtocolAndMapError(
        _ remoteSecretMonitorProtocol: any RemoteSecretMonitorProtocolProtocol,
        httpClient: any RemoteSecretHTTPClientProtocol
    ) async throws -> RemoteSecret? {
        do {
            return try await runRemoteSecretMonitorProtocol(
                remoteSecretMonitorProtocol,
                httpClient: httpClient
            )
        }
        catch let RemoteSecretMonitorError.InvalidParameter(message: message) {
            DDLogError("Remote secret invalid parameter: \(message)")
            throw RemoteSecretManagerError.invalidParameter
        }
        catch let RemoteSecretMonitorError.InvalidState(message: message) {
            DDLogError("Remote secret invalid state: \(message)")
            throw RemoteSecretManagerError.invalidState
        }
        catch let RemoteSecretMonitorError.ServerError(message: message) {
            DDLogError("Remote secret server error: \(message)")
            throw RemoteSecretManagerError.serverError
        }
        catch let RemoteSecretMonitorError.Timeout(message: message) {
            DDLogError("Remote secret timeout: \(message)")
            throw RemoteSecretManagerError.timeout
        }
        catch let RemoteSecretMonitorError.NotFound(message: message) {
            DDLogError("Remote secret not found: \(message)")
            throw RemoteSecretManagerError.remoteSecretNotFound
        }
        catch let RemoteSecretMonitorError.Blocked(message: message) {
            DDLogError("Remote secret blocked: \(message)")
            throw RemoteSecretManagerError.blocked
        }
        catch let RemoteSecretMonitorError.Mismatch(message: message) {
            DDLogError("Remote secret missmatch: \(message)")
            throw RemoteSecretManagerError.mismatch
        }
        catch {
            DDLogError("Remote secret unexpected error from libthreema: \(error)")
            throw RemoteSecretManagerError.unknown
        }
    }
    
    /// - Throws: According to the libthreema documentation this should only throw `RemoteSecretMonitorError`
    private func runRemoteSecretMonitorProtocol(
        _ remoteSecretMonitorProtocol: any RemoteSecretMonitorProtocolProtocol,
        httpClient: any RemoteSecretHTTPClientProtocol
    ) async throws -> RemoteSecret? {
        while true {
            switch try remoteSecretMonitorProtocol.poll() {
            case let .request(httpsRequest):
                // If we receive an instruction with a request, we execute it, handle its response or error and poll
                // again...
                let response = await RemoteSecretHelper.runHTTPSRequest(httpsRequest, httpClient: httpClient)
                try remoteSecretMonitorProtocol.response(response: response)
                
            case .schedule(timeout: let timeout, remoteSecret: var remoteSecret):
                // If the initial fetch fails (e.g. by being offline) libthreema might schedule a retry task instead of
                // throwing an error. Thus we need to account for that. At the same time libthreema guarantees that
                // eventually `remoteSecret` is non-nil or `poll()` will throw an error.
                if !remoteSecretFetchCompleted {
                    
                    // Important: To ensure we don't get another remote secret copy in memory we don't unwrap here
                    if remoteSecret != nil {
                        DDLogInfo("Remote secret fetched")
                        remoteSecretFetchCompleted = true

                        scheduleWaitTask(
                            in: timeout,
                            remoteSecretMonitorProtocol: remoteSecretMonitorProtocol,
                            httpClient: httpClient
                        )
                        
                        // Needed such that the remote secret can be zeroized after it is (copied &) wrapped
                        // The force-unwrap is safe as we check for `nil` above
                        let wrappedRemoteSecret = RemoteSecret(rawValue: remoteSecret!)
                        remoteSecret?.zeroize()
                        return wrappedRemoteSecret
                    }
                    else {
                        DDLogInfo("No remote secret fetched. Wait \(timeout) seconds...")
                        try await Task.sleep(seconds: timeout)
                    }
                }
                else {
                    scheduleWaitTask(
                        in: timeout,
                        remoteSecretMonitorProtocol: remoteSecretMonitorProtocol,
                        httpClient: httpClient
                    )
                    return nil
                }
            }
        }
    }
    
    // MARK: Schedule Task
    
    private func scheduleWaitTask(
        in interval: TimeInterval,
        remoteSecretMonitorProtocol: any RemoteSecretMonitorProtocolProtocol,
        httpClient: any RemoteSecretHTTPClientProtocol
    ) {
        DDLogInfo("Schedule wait task in \(interval) seconds")
        waitTask = Task.detached { [weak self] in
            try await Task.sleep(seconds: interval)
            
            self?.isMonitorCheckRunning.wrappedValue = true
            try Task.checkCancellation() // Ensure the task wasn't canceled while setting the check value
            await self?.runRemoteSecretMonitorProtocolAndHandleError(
                remoteSecretMonitorProtocol,
                httpClient: httpClient
            )
            self?.isMonitorCheckRunning.wrappedValue = false
        }
    }
}
