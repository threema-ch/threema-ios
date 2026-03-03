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

/// Public errors of RemoteSecret package
public enum RemoteSecretManagerError: Error, CustomStringConvertible, Equatable {
    case invalidParameter
    case invalidState
    case serverError
    case timeout
    case remoteSecretNotFound
    case blocked
    case mismatch
    
    case networkError
    /// Invalid Work/OnPrem credentials. Request them (again) from the user
    case invalidCredentials
    case exceededRateLimit
    
    case preexistingRemoteSecret
    case noThreemaIdentityAvailable
    case noRemoteSecretCredentialsAvailable
    case noWorkServerBaseURL

    case unknown
    
    public var description: String {
        switch self {
        case .invalidParameter:
            "Invalid parameter"
        case .invalidState:
            "Invalid state"
        case .serverError:
            "Server error"
        case .timeout:
            "Timeout"
        case .remoteSecretNotFound:
            "Remote secret not found"
        case .blocked:
            "Blocked"
        case .mismatch:
            "Mismatch"
        case .networkError:
            "Network error"
        case .invalidCredentials:
            "Invalid credentials"
        case .exceededRateLimit:
            "Exceeded rate limit"
        case .preexistingRemoteSecret:
            "Preexisting remote secret"
        case .noThreemaIdentityAvailable:
            "No Threema identity available"
        case .noRemoteSecretCredentialsAvailable:
            "No remote secret credentials available"
        case .noWorkServerBaseURL:
            "No Work/OnPrem base URL"
        case .unknown:
            "Unknown error"
        }
    }
}
