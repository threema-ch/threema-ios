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

public protocol RemoteSecretManagerProtocol: Sendable {
    /// Is remote secret active?
    ///
    /// Only use this for checks that show/hide certain info
    var isRemoteSecretEnabled: Bool { get }
    
    /// All functions to encrypt data with remote secret
    var crypto: RemoteSecretCryptoProtocol { get }
    
    /// Invoke check in the background if remote secret is still valid
    ///
    /// Errors are handled internally
    func checkValidity()
    
    /// Stop remote secret monitoring during reset of app
    ///
    /// - Warning: This only succeeds if the remote secret information is not in the keychain anymore
    func stopMonitoring() async
    
    func encryptDataIfNeeded(_ data: Data) -> Data

    func decryptDataIfNeeded(_ data: Data) -> Data
}

extension RemoteSecretManagerProtocol {
    
    // MARK: - Data
    
    public func encryptDataIfNeeded(_ data: Data) -> Data {
        if isRemoteSecretEnabled {
            crypto.encrypt(data)
        }
        else {
            data
        }
    }
    
    public func decryptDataIfNeeded(_ data: Data) -> Data {
        if isRemoteSecretEnabled {
            crypto.decrypt(data)
        }
        else {
            data
        }
    }
    
    public func encryptDataIfNeeded(_ data: Data?) -> Data? {
        guard let data else {
            return nil
        }
        
        let encryptedData: Data = encryptDataIfNeeded(data)
        return encryptedData
    }
    
    public func decryptDataIfNeeded(_ data: Data?) -> Data? {
        guard let data else {
            return nil
        }
        
        let decryptedData: Data = decryptDataIfNeeded(data)
        return decryptedData
    }
}
