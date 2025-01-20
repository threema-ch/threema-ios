//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

public class URLSessionManager {
    
    // MARK: - Properties

    /// Shared URLSessionManager using a DefaultURLSessionProvider
    public static let shared = URLSessionManager(with: DefaultURLSessionProvider())
    
    let sessionProvider: URLSessionProvider
    
    private var sessionStoreMutationLock = DispatchQueue(label: "sessionStoreMutationLock")
    private(set) var sessionStore = [Int: URLSession]()
    
    // MARK: - Lifecycle

    init(with sessionProvider: URLSessionProvider) {
        self.sessionProvider = sessionProvider
    }
    
    // MARK: - Sessions
      
    /// Returns the session for a given delegate if it exists. Otherwise it creates one and stores it if a delegate is
    /// provided.
    /// - Parameters:
    ///   - delegate: Optional URLSessionDelegate for created session
    ///   - createAsBackgroundSession: If created session is a background session
    /// - Returns: Fetched or created URLSession
    func storedSession(for delegate: URLSessionDelegate?, createAsBackgroundSession: Bool) -> URLSession {
        sessionStoreMutationLock.sync {
    
            // If no delegate is provided, we return a default session
            guard let delegate else {
                return sessionProvider.defaultSession()
            }
            
            let hash = delegate.hash
            
            // We return the stored session if it exists
            if let storedSession = sessionStore[hash] {
                return storedSession
            }
            
            // No session found, creating new one. If it is a background session we store it. Else we just return the
            // default session
            let createdSession: URLSession =
                if createAsBackgroundSession {
                    sessionProvider.backgroundSession(
                        identifier: String(hash),
                        delegate: delegate
                    )
                }
                else {
                    sessionProvider.defaultSession(delegate: delegate)
                }
            
            sessionStore[hash] = createdSession
            return createdSession
        }
    }
    
    /// Invalidates and cancels session for a given delegate
    /// - Parameter delegate: URLSessionDelegate of to be canceled session
    public func invalidateAndCancelSession(for delegate: URLSessionDelegate) {
        sessionStoreMutationLock.sync {
            let identifier = delegate.hash
            if let session = sessionStore[identifier] {
                session.invalidateAndCancel()
            }
        }
    }
}
