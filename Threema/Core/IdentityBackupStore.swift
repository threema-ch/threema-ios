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

import CocoaLumberjackSwift
import FileUtility
import Keychain

@objc final class IdentityBackupStore: NSObject {
    
    public enum Error: Swift.Error {
        case saveIdentityBackupFailed
        case saveIdentityBackupToKeychainFailed
        case saveIdentityBackupToFileFailed
        case backupFilePathMissing
        case deleteIdentityBackupFromFileFailed
    }
     
    private static let backupFileName = "idbackup.txt"
    private static let backupFileURL = FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(backupFileName)
    
    @objc static func loadIdentityBackup() -> String? {
        if let backup = loadIdentityBackupFromKeychain() {
            return backup
        }
        
        return loadIdentityBackupFromFile()
    }
    
    static func saveIdentityBackup(_ backupData: String) throws {
        do {
            try saveIdentityBackupToKeychain(backupData)
            try saveIdentityBackupToFile(backupData)
        }
        catch {
            throw Error.saveIdentityBackupFailed
        }
    }
    
    @objc static func deleteIdentityBackup() throws {
        do {
            try KeychainManager.deleteIdentityBackup()
            try deleteIdentityBackupFromFile()
        }
        catch {
            DDLogError("Couldn't delete identity backup from keychain: \(error.localizedDescription)")
            throw error
        }
    }
    
    @objc static func syncKeychainWithFile() {
        // Check for an ID backup in the keychain and in a file within the app data container. If one of them is
        // missing, restore it (keychain takes priority). We need both the keychain entry and the file, as the
        // keychain entry survives app deletion/reinstallation, while the file survives device backup/restore
        // via iCloud or unencrypted iTunes backup.
        let keychainBackup = loadIdentityBackupFromKeychain()
        let fileBackup = loadIdentityBackupFromFile()
        
        if let keychainBackup,
           !keychainBackup.isEmpty {
            if fileBackup == nil || keychainBackup != fileBackup {
                // Write file again
                try? saveIdentityBackupToFile(keychainBackup)
            }
        }
        else if let fileBackup,
                !fileBackup.isEmpty,
                keychainBackup == nil || fileBackup != keychainBackup {
            // Write keychain entry again
            try? saveIdentityBackupToKeychain(fileBackup)
        }
    }
}

/// Private functions
extension IdentityBackupStore {
    private static func loadIdentityBackupFromKeychain() -> String? {
        do {
            return try KeychainManager.loadIdentityBackup()
        }
        catch {
            DDLogError("Couldn't load identity backup from keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func loadIdentityBackupFromFile() -> String? {
        guard let backupFileURL,
              FileUtility.shared.fileExists(at: backupFileURL),
              let backup = try? String(contentsOfFile: backupFileURL.path(), encoding: .utf8),
              !backup.isEmpty else {
            DDLogError("Couldn't load identity backup from file")
            return nil
        }
        return backup
    }
    
    private static func deleteIdentityBackupFromFile() throws {
        guard let backupFileURL else {
            DDLogError("Couldn't delete identity backup from file")
            throw Error.deleteIdentityBackupFromFileFailed
        }
        
        FileUtility.shared.deleteIfExists(at: backupFileURL)
    }
    
    private static func saveIdentityBackupToKeychain(_ backupData: String) throws {
        do {
            try KeychainManager.storeIdentityBackup(backupData)
        }
        catch {
            DDLogError("Couldn't store identity backup to keychain: \(error.localizedDescription)")
            throw Error.saveIdentityBackupToKeychainFailed
        }
    }
    
    private static func saveIdentityBackupToFile(_ backupData: String) throws {
        guard let backupFileURL else {
            throw Error.backupFilePathMissing
        }
        guard FileUtility.shared.write(
            contents: Data(backupData.utf8),
            to: backupFileURL
        ) else {
            DDLogError("Couldn't store identity backup to file")
            throw Error.saveIdentityBackupToFileFailed
        }
    }
}
