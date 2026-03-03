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
import RemoteSecretProtocol

enum RemoteSecretManagerExtensionError: Error {
    case stringEncodingFailed
    case invalidBase64String
}

extension RemoteSecretManagerProtocol {

    // MARK: - Data

    func decryptDataToStringIfNeeded(_ data: Data) throws -> String {
        let decryptingData: Data =
            if isRemoteSecretEnabled {
                crypto.decrypt(data)
            }
            else {
                data
            }
        
        guard let decoded = String(data: decryptingData, encoding: .utf8) else {
            /// Due to this being an extension, we create a new error type, so it's
            /// not confused with any existing errors.
            throw RemoteSecretManagerExtensionError.stringEncodingFailed
        }

        return decoded
    }

    func decryptDataToStringIfNeeded(_ data: Data?) throws -> String? {
        guard let data else {
            return nil
        }
        
        let decrypted: String = try decryptDataToStringIfNeeded(data)
        return decrypted
    }
    
    // MARK: - String

    func encryptToBase64StringIfNeeded(_ string: String) -> String {
        if isRemoteSecretEnabled {
            crypto.encrypt(string).base64EncodedString()
        }
        else {
            string
        }
    }
    
    func encryptToBase64StringIfNeeded(_ string: String?) -> String? {
        if isRemoteSecretEnabled,
           let string {
            crypto.encrypt(string).base64EncodedString()
        }
        else {
            string
        }
    }

    func decryptBase64StringIfNeeded(_ string: String) throws -> String? {
        if isRemoteSecretEnabled {
            guard let data = Data(base64Encoded: string) else {
                throw RemoteSecretManagerExtensionError.invalidBase64String
            }
                
            return crypto.decrypt(data)
        }
        else {
            return string
        }
    }

    func decryptBase64StringIfNeeded(_ string: String?) throws -> String? {
        guard let string else {
            return nil
        }
        
        return try decryptBase64StringIfNeeded(string)
    }
    
    func encryptStringIfNeeded(_ string: String) -> Data {
        if isRemoteSecretEnabled {
            crypto.encrypt(string)
        }
        else {
            Data(string.utf8)
        }
    }

    func encryptStringIfNeeded(_ string: String?) -> Data? {
        guard let string else {
            return nil
        }
        
        let encrypted: Data = encryptStringIfNeeded(string)
        return encrypted
    }
}
