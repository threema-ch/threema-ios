//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

import Ed25519
import Foundation

class OnPremConfigVerifier {
    private let trustedPublicKeys: [Data]
    
    /// - Parameter publicKey: The public key in Base64
    init(trustedPublicKeys: [String]) {
        self.trustedPublicKeys = trustedPublicKeys.map { publicKey -> Data in
            Data(base64Encoded: publicKey)!
        }
    }
    
    /// - Parameter oppfData: The OPPF data to verify
    ///
    /// - Returns: the resulting JSON document
    func verify(oppfData: String) throws -> OnPremConfig {
        // Extract signature
        guard let lfIndex = oppfData.lastIndex(of: "\n") else {
            throw OnPremConfigError.badInputOppfData
        }
        
        let jsonData = oppfData[..<lfIndex]
        guard let sig = Data(base64Encoded: String(oppfData[oppfData.index(lfIndex, offsetBy: 1)...])) else {
            throw OnPremConfigError.badInputOppfData
        }
        
        // Verify signature
        var valid = false
        var chosenPublicKey: Data?
        for publicKey in trustedPublicKeys {
            let edPublicKey = try PublicKey([UInt8](publicKey))
            if try edPublicKey.verify(signature: [UInt8](sig), message: [UInt8](Data(jsonData.utf8))) {
                valid = true
                chosenPublicKey = publicKey
                break
            }
        }
        
        if !valid {
            throw OnPremConfigError.badSignature
        }
        
        // Parse config
        let decoder = JSONDecoder()
        let dateFormat = Foundation.DateFormatter()
        dateFormat.timeZone = .current
        dateFormat.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(dateFormat)
        let config = try decoder.decode(OnPremConfig.self, from: Data(jsonData.utf8))
        
        // Check that the version is supported
        if config.version != "1.0" {
            throw OnPremConfigError.unsupportedVersion
        }
        
        // Check that the signature key matches
        if config.signatureKey != chosenPublicKey {
            throw OnPremConfigError.signatureKeyMismatch
        }
        
        // Check that the license is not expired (add one day to account for the fact
        // that the expiration date is defined as "not valid after")
        let expires = config.license.expires + 86400
        if expires < Date() {
            throw OnPremConfigError.licenseExpired
        }
        
        return config
    }
}
