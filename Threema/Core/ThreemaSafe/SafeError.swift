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
import ThreemaMacros

indirect enum SafeError: Error, CustomStringConvertible, Equatable {
    
    case backupError(BackupError)
    case restoreError(RestoreError)
    
    // General errors
    case resolvingDefaultServerFailed
    case invalidURL
    
    case nestedError(SafeError, message: String)
    case unknownError(message: String)
    
    enum BackupError: Error, CustomStringConvertible {
        case badPassword
        case invalidKey
        case invalidID
        case invalidData
        case backupTooBig
        case encryptionFailed
        
        var description: String {
            switch self {
            case .badPassword:
                #localize("safe_bad_password")
            case .invalidKey:
                #localize("safe_invalid_key")
            case .invalidID:
                #localize("safe_invalid_id")
            case .invalidData:
                #localize("safe_invalid_data")
            case .backupTooBig:
                #localize("safe_upload_size_exceeded")
            case .encryptionFailed:
                #localize("safe_encryption_failed")
            }
        }
    }
    
    enum RestoreError: Error, CustomStringConvertible {
        case invalidInput
        
        case noBackupFound
        case invalidResponse
        case decodingFailed
        
        case versionMismatch
        case invalidMasterKey
        case invalidClientKey
        case invalidData

        case remoteSecretError
        
        var description: String {
            switch self {
            case .invalidInput:
                #localize("safe_invalid_input")
            case .noBackupFound:
                #localize("safe_no_backup_found")
            case .invalidResponse:
                #localize("safe_invalid_response")
            case .decodingFailed:
                #localize("safe_decoding_failed")
            case .versionMismatch:
                #localize("safe_version_mismatch")
            case .invalidMasterKey:
                #localize("safe_invalid_content")
            case .invalidClientKey:
                #localize("safe_invalid_key")
            case .invalidData:
                #localize("safe_invalid_data")
            case .remoteSecretError:
                #localize("safe_rs_error")
            }
        }
    }
    
    var description: String {
        switch self {
        case let .backupError(backupError):
            backupError.description
            
        case let .restoreError(restoreError):
            restoreError.description
            
        case .resolvingDefaultServerFailed:
            #localize("safe_resolving_server_failed")
            
        case .invalidURL:
            #localize("safe_invalid_url")
            
        case let .nestedError(safeError, message):
            "\(safeError.description): \(message)"
            
        case let .unknownError(message):
            "\(#localize("safe_unknown_error")): \(message)"
        }
    }
}
