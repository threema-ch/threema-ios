//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

/// Obtains and manages authentication tokens for access to OnPrem servers.
public class AuthTokenManager: NSObject {
    public typealias AuthTokenCompletionHandler = (String?, Error?) -> Void

    private var authToken: String?
    private var queue = DispatchQueue(label: "AuthTokenManager")
    private var isFetching = false
    private var completionHandlers: [AuthTokenCompletionHandler] = []
    
    private static let authTokenManager = AuthTokenManager()
    
    @objc public static func shared() -> AuthTokenManager {
        authTokenManager
    }
    
    @objc public func obtainToken(completionHandler: @escaping AuthTokenCompletionHandler) {
        if !LicenseStore.isOnPrem() {
            completionHandler(nil, nil)
            return
        }
        
        queue.async {
            if self.authToken != nil {
                // Cached token
                completionHandler(self.authToken, nil)
                return
            }
            
            self.completionHandlers.append(completionHandler)
            
            if !self.isFetching {
                self.isFetching = true
                ServerAPIConnector().obtainAuthToken(onCompletion: { authToken in
                    self.queue.async {
                        self.isFetching = false
                        self.authToken = authToken
                        for completionHandler in self.completionHandlers {
                            completionHandler(authToken, nil)
                        }
                        self.completionHandlers.removeAll()
                    }
                }, onError: { err in
                    self.queue.async {
                        for completionHandler in self.completionHandlers {
                            completionHandler(nil, err)
                        }
                        self.completionHandlers.removeAll()
                    }
                })
            }
        }
    }
    
    public func clearCache() {
        queue.async {
            self.authToken = nil
        }
    }
}
