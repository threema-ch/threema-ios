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

import libthreemaSwift

// TODO: (IOS-5275) Remove after libthreema is used somewhere in our codebase

/// Simple function run the ID backup code of libthreema (with fake inputs)
///
/// This should only be used as long as libthreema is not used somewhere else to ensure function calls into libhreema
/// work. (IOS-5275)
@available(*, deprecated, message: "This should only be used for integration testing")
public struct libthreemaIntegrationTest {
    public enum Error: Swift.Error {
        case notMatchingBackupData
    }
    
    public static func run() throws {
        let fakeThreemaID = "ABDCEFGH"
        let fakeClientKey = Data(repeating: 0x01, count: 32)
        // swiftformat:disable:next acronyms
        let backupData = BackupData(threemaId: fakeThreemaID, ck: fakeClientKey)
        
        let thisIsABadPassword = "abcdefgh"

        // Encrypt
        let backupString = try encryptIdentityBackup(password: thisIsABadPassword, backupData: backupData)
        
        // Decrypt
        let decryptedBackupData = try decryptIdentityBackup(password: thisIsABadPassword, encryptedBackup: backupString)
        
        guard decryptedBackupData == backupData else {
            throw Error.notMatchingBackupData
        }
    }
}
