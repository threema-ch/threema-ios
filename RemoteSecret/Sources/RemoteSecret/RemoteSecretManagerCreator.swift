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

import Foundation
import Keychain
import libthreemaSwift
import RemoteSecretProtocol
import ThreemaEssentials

/// Create remote secret manager
///
/// - Note: This should only be called once during the app launch or setup process
public final class RemoteSecretManagerCreator {
    
    private let appInfo: AppInfo
    private let httpClient: any RemoteSecretHTTPClientProtocol
    private let remoteSecretCreate: any RemoteSecretCreateProtocol
    private let remoteSecretMonitor: any RemoteSecretMonitorSwiftProtocol
    private let keychainManagerType: any KeychainManagerProtocol.Type
    
    // MARK: - Lifecycle
    
    /// Create a new creator
    /// - Parameters:
    ///   - appInfo: Info about the current app
    ///   - httpClient: HTTP client to use for all remote secret requests
    ///   - keychainManagerType: Keychain to use to access remote secret credentials
    @MainActor
    public convenience init(
        appInfo: AppInfo,
        httpClient: any RemoteSecretHTTPClientProtocol,
        keychainManagerType: any KeychainManagerProtocol.Type
    ) {
        self.init(
            appInfo: appInfo,
            httpClient: httpClient,
            remoteSecretCreate: RemoteSecretCreate(appInfo: appInfo, httpClient: httpClient),
            remoteSecretMonitor: RemoteSecretMonitor(appInfo: appInfo, httpClient: httpClient),
            keychainManagerType: keychainManagerType
        )
    }
    
    /// Full initializer for testing
    init(
        appInfo: AppInfo,
        httpClient: any RemoteSecretHTTPClientProtocol,
        remoteSecretCreate: any RemoteSecretCreateProtocol,
        remoteSecretMonitor: any RemoteSecretMonitorSwiftProtocol,
        keychainManagerType: any KeychainManagerProtocol.Type
    ) {
        self.appInfo = appInfo
        self.httpClient = httpClient
        self.remoteSecretCreate = remoteSecretCreate
        self.remoteSecretMonitor = remoteSecretMonitor
        self.keychainManagerType = keychainManagerType
    }
    
    // MARK: - Public interface
    
    /// Create a new remote secret
    ///
    /// This call should "block" progress and wait in the UI. If this fails an error should be shown to the user
    ///
    /// - Parameters:
    ///   - workServerBaseURL: Base URL of work API server
    ///   - licenseUsername: License username
    ///   - licensePassword: License password
    ///   - identity: Identity of user
    ///   - clientKey: Client key of user
    /// - Returns: Remote secret manager
    /// - Throws: `RemoteSecretManagerError` or `KeychainManager.KeychainManagerError`
    public func create(
        workServerBaseURL: String,
        licenseUsername: String,
        licensePassword: String,
        identity: ThreemaIdentity,
        clientKey: Data
    ) async throws -> any RemoteSecretManagerProtocol {
        guard try keychainManagerType.loadRemoteSecret() == nil else {
            throw RemoteSecretManagerError.preexistingRemoteSecret
        }
        
        // Run creation task
        let (authenticationToken, identityHash) = try await remoteSecretCreate.run(
            workServerBaseURL: workServerBaseURL,
            licenseUsername: licenseUsername,
            licensePassword: licensePassword,
            identity: identity,
            clientKey: clientKey
        )
        
        // Store remote secret in keychain
        try keychainManagerType.storeRemoteSecret(
            authenticationToken: authenticationToken,
            identityHash: identityHash
        )
                
        // Immediately start monitor. We want to know it when this fails.
        // This is leads to another challenge response call to the RS endpoint. We do this so ensure the monitoring
        // starts
        return try await initializeAndStartMonitor(
            identity: identity,
            throwError: true
        ) {
            workServerBaseURL
        }
    }
    
    /// Initializes an empty remote secret manager
    /// - Returns: Empty remote secret manager
    public func initializeEmptyRemoteSecretManager() -> any RemoteSecretManagerProtocol {
        EmptyRemoteSecretManager()
    }
    
    /// Initialize remote secret
    ///
    /// This fetches the remote secret from the sever and starts monitoring the RS changes
    ///
    /// This call should "block" progress and wait in the UI. If this fails an error should be shown to the user
    ///
    /// - Parameters:
    ///   - identity: Optional `ThreemaIdentity`, inject when identity is not yet present in keychain, e.g. during setup
    ///   - throwError: Should be true if Remote Secret enabled
    ///   - workServerBaseURL: Closure to load work server url
    /// - Returns: Remote secret manager
    /// - Throws: `RemoteSecretManagerError` or `KeychainManager.KeychainManagerError`
    public func initialize(
        identity: ThreemaIdentity? = nil,
        throwError: Bool = false,
        workServerBaseURL: () async -> String?
    ) async throws -> any RemoteSecretManagerProtocol {
        // The closure for `workServerBaseURL` ensures that we attempt to load the server url only if RS is actually
        // setup (i.e. in keychain)
        
        guard let identity = try keychainManagerType.loadThreemaIdentity() ?? identity else {
            if throwError {
                throw RemoteSecretManagerError.noThreemaIdentityAvailable
            }

            return EmptyRemoteSecretManager()
        }
        
        return try await initializeAndStartMonitor(
            identity: identity,
            throwError: throwError,
            workServerBaseURL: workServerBaseURL
        )
    }
    
    // MARK: - Private helper
    
    private func initializeAndStartMonitor(
        identity: ThreemaIdentity,
        throwError: Bool,
        workServerBaseURL: () async -> String?
    ) async throws -> any RemoteSecretManagerProtocol {
        
        // Threema identity needs to be injected because during creation it cannot be loaded from Keychain
        
        guard let (authenticationToken, identityHash) = try keychainManagerType.loadRemoteSecret() else {
            // RS is not activated/created
            if throwError {
                throw RemoteSecretManagerError.noRemoteSecretCredentialsAvailable
            }
            
            return EmptyRemoteSecretManager()
        }
        
        guard let workServerBaseURL = await workServerBaseURL() else {
            throw RemoteSecretManagerError.noWorkServerBaseURL
        }
        
        // Create & start monitor
        let remoteSecret = try await remoteSecretMonitor.createAndStart(
            workServerBaseURL: workServerBaseURL,
            identity: identity,
            remoteSecretAuthenticationToken: authenticationToken,
            remoteSecretIdentityHash: identityHash
        )
        
        // Create remote secret crypto
        let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)
                
        // Create remote secret manager
        let remoteSecretManager = RemoteSecretManager(
            crypto: remoteSecretCrypto,
            monitor: remoteSecretMonitor,
            keychainManagerType: keychainManagerType
        )
                
        return remoteSecretManager
    }
}
