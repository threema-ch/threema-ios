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
import ThreemaEssentials

// This has "Swift" in the name to prevent a name clash with libthreema's `RemoteSecretMonitorProtocol`
protocol RemoteSecretMonitorSwiftProtocol: Sendable {
    
    /// Fetch remote secret, and create & starting monitor
    ///
    /// - Parameters:
    ///   - workServerBaseURL: Base URL of work API server
    ///   - identity: Threema identity of user
    ///   - remoteSecretAuthenticationToken: Remote secret authentication token (rsat)
    ///   - remoteSecretIdentityHash: Remote secret identity hash (rshid)
    /// - Returns: Remote secret
    /// - Throws: `RemoteSecretManagerError`
    func createAndStart(
        workServerBaseURL: String,
        identity: ThreemaIdentity,
        remoteSecretAuthenticationToken: Data,
        remoteSecretIdentityHash: Data
    ) async throws -> RemoteSecret
    
    /// Enforce a monitor check right now
    func runCheck() async
    
    /// Stop monitor
    ///
    /// - Warning: Only call this during the reset of the app
    func stop() async
}
