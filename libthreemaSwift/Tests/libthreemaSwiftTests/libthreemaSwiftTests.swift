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
import Testing
@testable import libthreemaSwift

@Test
func encryptedBackup() throws {
    let expectedThreemaID = "ABDCEFGH"
    let expectedClientKey = Data(repeating: 0x01, count: 32)
    // swiftformat:disable:next acronyms
    let expectedBackupData = BackupData(threemaId: expectedThreemaID, ck: expectedClientKey)
    
    let password = "abcdefgh"

    // Encrypt
    let backupString = try encryptIdentityBackup(password: password, backupData: expectedBackupData)
    #expect(backupString.isEmpty == false)
    
    // Decrypt
    let decryptedBackupData = try decryptIdentityBackup(password: password, encryptedBackup: backupString)
    #expect(decryptedBackupData == expectedBackupData)
}
