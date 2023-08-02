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

import Foundation

/// Helper for easier handling of NaCl in Swift
extension NaClCrypto {
    /// Representation of an NaCl key pair in Swift
    struct KeyPair {
        let publicKey: Data
        let privateKey: Data
    }
    
    enum Error: Swift.Error {
        case unableToGenerateKeyPair
    }
    
    /// Generate a new key pair
    /// - Returns: New key pair if successfully created
    /// - Throws: `NaClCrypto.Error` if generation fails
    func generateNewKeyPair() throws -> KeyPair {
        var publicKey: NSData?
        var privateKey: NSData?
        
        generateKeyPairPublicKey(&publicKey, secretKey: &privateKey)
        
        guard let publicKey, let privateKey else {
            throw Error.unableToGenerateKeyPair
        }
        
        return KeyPair(publicKey: Data(publicKey), privateKey: Data(privateKey))
    }
}
