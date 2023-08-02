//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import GroupCalls

enum GroupCallsHTTPHelperError: Error {
    case unknownError
}

/// Fetches and caches SFU tokens
/// Will attempt at most one fetch
public actor GroupCallsSFUTokenFetcher: GroupCallsSFUTokenFetchAdapterProtocol {
    fileprivate let myIdentityStore = MyIdentityStore.shared()
    
    fileprivate var cachedCredentials: SFUToken?
    
    fileprivate var currentTask: Task<SFUToken, Error>?
    
    public func sfuCredentials() async throws -> SFUToken {
        guard let currentTask, try await currentTask.value.stillValid else {
            DDLogVerbose("[GroupCall] Token never fetched or not valid anymore. Fetch again.")
            let newTask = Task {
                try await fetchCredentials()
            }
            
            currentTask = newTask
            return try await newTask.value
        }
        
        DDLogVerbose("[GroupCall] Return cached token")
        return try await currentTask.value
    }
    
    private func fetchCredentials() async throws -> SFUToken {
        try await withCheckedThrowingContinuation { checkedContinuation in
            ServerAPIConnector().obtainSFUCredentials(myIdentityStore) { (dict: [AnyHashable: Any]?) in
                guard let jsonDict = dict as? [String: Any] else {
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                guard let baseURL = jsonDict["sfuBaseUrl"] as? String else {
                    DDLogError("Could not decode SFUBaseURl")
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                guard let hostNameSuffixes = jsonDict["allowedSfuHostnameSuffixes"] as? [String] else {
                    DDLogError("Could not decode allowedSfuHostnameSuffixes")
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                guard let sfuToken = jsonDict["sfuToken"] as? String else {
                    DDLogError("Could not decode sfuToken")
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                guard let expiration = jsonDict["expiration"] as? Int else {
                    DDLogError("Could not decode expiration")
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                let token = SFUToken(
                    sfuBaseURL: baseURL,
                    hostNameSuffixes: hostNameSuffixes,
                    sfuTOken: sfuToken,
                    expiration: expiration
                )
                
                self.cachedCredentials = token
                
                checkedContinuation.resume(returning: token)
            } onError: { error in
                guard let error else {
                    DDLogError("An unknown error occurred when getting the SFU token")
                    checkedContinuation.resume(throwing: GroupCallsHTTPHelperError.unknownError)
                    return
                }
                
                DDLogError("An unknown error when getting the SFU token: \(error.localizedDescription)")
                
                checkedContinuation.resume(throwing: error)
            }
        }
    }
}
