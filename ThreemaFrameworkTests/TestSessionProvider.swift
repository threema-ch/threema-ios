//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import ThreemaFramework

class TestSessionProvider: URLSessionProvider {

    // MARK: - Sessions
    
    /// Provides a standard ephemeral session
    func defaultSession(delegate: URLSessionDelegate?) -> URLSession {
        // We first need to create the configuration. Changes made to a session after its initialization are not
        // respected.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        
        // General
        configuration.allowsCellularAccess = true
        // configuration.waitsForConnectivity = true
        
        // Caching, this might not be needed since configuration is ephemeral anyways
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil

        if let delegate {
            return URLSession(
                configuration: configuration,
                delegate: delegate,
                delegateQueue: OperationQueue.current
            )
        }
        else {
            return URLSession(configuration: configuration)
        }
    }
    
    /// Creates a background session
    /// - Parameters:
    ///   - identifier: Identifier for session
    ///   - delegate: Delegate for session
    /// - Returns: Created URLSession
    func backgroundSession(identifier: String, delegate: URLSessionDelegate) -> URLSession {
        // Return default session, because background session not working in unit tests
        defaultSession(delegate: delegate)
    }
}
