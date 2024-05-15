//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

final class DefaultRendezvousCryptoTests: XCTestCase {
    
    // MARK: - Authentication keys tests
    
    func testEncryptionInitiator() throws {
        let expectedHexString = "6774c06d35c88aad364a29ae63e5d4af1aeeff92e6e6f1"
        
        let role = Rendezvous.Role.initiator
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let dataToEncrypt = Data("threema".utf8)
        
        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )
        
        // Sequence number needs to be 1
        let actualEncryptedData = try rendezvousCrypto.encrypt(dataToEncrypt)
        
        // Validate
        
        XCTAssertEqual(actualEncryptedData.hexString, expectedHexString)
    }
    
    // This is the inverse of `testEncryptionInitiator()`
    func testDecryptionResponder() throws {
        let expectedData = Data("threema".utf8)
        
        let role = Rendezvous.Role.responder
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let dataToDecrypt = Data([
            0x67, 0x74, 0xC0, 0x6D, 0x35, 0xC8, 0x8A, 0xAD, 0x36, 0x4A, 0x29, 0xAE, 0x63, 0xE5, 0xD4, 0xAF,
            0x1A, 0xEE, 0xFF, 0x92, 0xE6, 0xE6, 0xF1,
        ])

        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )

        // Sequence number needs to be 1
        let actualDecryptedData = try rendezvousCrypto.decrypt(dataToDecrypt)

        // Validate
        
        XCTAssertEqual(actualDecryptedData, expectedData)
    }
    
    func testEncryptionResponder() throws {
        let expectedHexString = "4ad02e1e879e64de5c030833ab4393e723ed951fb841cc"
        
        let role = Rendezvous.Role.responder
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let dataToEncrypt = Data("threema".utf8)
        
        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )
        
        // Sequence number needs to be 1
        let actualEncryptedData = try rendezvousCrypto.encrypt(dataToEncrypt)
        
        // Validate
        
        XCTAssertEqual(actualEncryptedData.hexString, expectedHexString)
    }
    
    // This is the inverse of `testEncryptionResponder()`
    func testDecryptionInitiator() throws {
        let expectedData = Data("threema".utf8)

        let role = Rendezvous.Role.initiator
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let dataToDecrypt = Data([
            0x4A, 0xD0, 0x2E, 0x1E, 0x87, 0x9E, 0x64, 0xDE, 0x5C, 0x03, 0x08, 0x33, 0xAB, 0x43, 0x93, 0xE7,
            0x23, 0xED, 0x95, 0x1F, 0xB8, 0x41, 0xCC,
        ])
        
        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )

        // Sequence number needs to be 1
        let actualDecryptedData = try rendezvousCrypto.decrypt(dataToDecrypt)

        // Validate
        
        XCTAssertEqual(actualDecryptedData, expectedData)
    }
    
    // MARK: - Transport keys tests
    
    func testTransportEncryptionInitiator() throws {
        let expectedPathHashHex = "580288fa0eee0af16a76be8d54ceb90b01634a3031141fca02540f6045467e7e"
        let expectedHexString = "0c88a55e4b23492638bd5f68542cdf9f4c1e6ce87136fc"
        
        // Derived ETK: 1c4ced205e274285121373dc8ff5c7f5c81e715ee65876444f3f8e04ec504676
        // STK: e78feea613e0a1529f639e3d383ce67feb10c1b4c0d04196b9fce38969cb55ec
        // RIDTK: 4086f38504a477e4a8fc85c67fa91f15341b45323c2b5a8e79bb83b47959f9de
        // RRDTK: b6ee98fe4fa9970576d5d1026f64f4f1e563c39879c15c0c5ba7ce74573aa96f
        
        // Inputs
        
        let role = Rendezvous.Role.initiator
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let localEphemeralTransportKeyPair = NaClCrypto.KeyPair(
            publicKey: Data(), // This is not a valid public key
            privateKey: Data(repeating: 0x01, count: 32)
        )
        let remotePublicEphemeralTransportKey = Data(repeating: 0x01, count: 32)
        
        let dataToEncrypt = Data("threema".utf8)
        
        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )
        
        let actualRendezvousPathHash = try rendezvousCrypto.switchToTransportKeys(
            localEphemeralTransportKeyPair: localEphemeralTransportKeyPair,
            remotePublicEphemeralTransportKey: remotePublicEphemeralTransportKey
        )
        
        // Sequence number needs to be 1
        let actualEncryptedData = try rendezvousCrypto.encrypt(dataToEncrypt)

        // Validate

        XCTAssertEqual(actualRendezvousPathHash.hexString, expectedPathHashHex)
        XCTAssertEqual(actualEncryptedData.hexString, expectedHexString)
    }
    
    // This is the inverse of `testTransportEncryptionInitiator()`
    func testTransportDecryptionResponder() throws {
        let expectedPathHashHex = "580288fa0eee0af16a76be8d54ceb90b01634a3031141fca02540f6045467e7e"
        let expectedData = Data("threema".utf8)
        
        // Derived ETK: 1c4ced205e274285121373dc8ff5c7f5c81e715ee65876444f3f8e04ec504676
        // STK: e78feea613e0a1529f639e3d383ce67feb10c1b4c0d04196b9fce38969cb55ec
        // RIDTK: 4086f38504a477e4a8fc85c67fa91f15341b45323c2b5a8e79bb83b47959f9de
        // RRDTK: b6ee98fe4fa9970576d5d1026f64f4f1e563c39879c15c0c5ba7ce74573aa96f
        
        // Inputs
        
        let role = Rendezvous.Role.responder
        let authenticationKey = Data(repeating: 0x01, count: 32)
        let pathID: UInt32 = 1
        
        let localEphemeralTransportKeyPair = NaClCrypto.KeyPair(
            publicKey: Data(), // This is not a valid public key
            privateKey: Data(repeating: 0x01, count: 32)
        )
        let remotePublicEphemeralTransportKey = Data(repeating: 0x01, count: 32)
        
        let dataToDecrypt = Data([
            0x0C, 0x88, 0xA5, 0x5E, 0x4B, 0x23, 0x49, 0x26, 0x38, 0xBD, 0x5F, 0x68, 0x54, 0x2C, 0xDF, 0x9F,
            0x4C, 0x1E, 0x6C, 0xE8, 0x71, 0x36, 0xFC,
        ])
                
        // Run
        
        let rendezvousCrypto = try DefaultRendezvousCrypto(
            role: role,
            authenticationKey: authenticationKey,
            pathID: pathID
        )
        
        let actualRendezvousPathHash = try rendezvousCrypto.switchToTransportKeys(
            localEphemeralTransportKeyPair: localEphemeralTransportKeyPair,
            remotePublicEphemeralTransportKey: remotePublicEphemeralTransportKey
        )
        
        // Sequence number needs to be 1
        let actualDecryptedData = try rendezvousCrypto.decrypt(dataToDecrypt)

        // Validate

        XCTAssertEqual(actualRendezvousPathHash.hexString, expectedPathHashHex)
        XCTAssertEqual(actualDecryptedData, expectedData)
    }
}
