import Foundation
import Testing
@testable import libthreemaSwift

@Test
func encryptedBackup() throws {
    let expectedThreemaID = "ABDCEFGH"
    let expectedClientKey = Data(repeating: 0x01, count: 32)
    // swiftformat:disable:next acronyms
    let expectedBackupData = IdentityBackupData(threemaId: expectedThreemaID, clientKey: expectedClientKey)
    
    let password = "abcdefgh"

    // Encrypt
    let backupString = try encryptIdentityBackup(password: password, backupData: expectedBackupData)
    #expect(backupString.isEmpty == false)
    
    // Decrypt
    let decryptedBackupData = try decryptIdentityBackup(password: password, encryptedBackup: backupString)
    #expect(decryptedBackupData == expectedBackupData)
}
