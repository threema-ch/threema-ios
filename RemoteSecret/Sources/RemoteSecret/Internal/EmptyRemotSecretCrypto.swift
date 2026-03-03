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

struct EmptyRemoteSecretCrypto: RemoteSecretCryptoProtocol {
    let coder: any SendableRemoteSecretCodable = EmptyRemoteSecretCoder()
    
    func encrypt(_ data: inout Data) {
        // no-op
    }
    
    func decrypt(_ data: inout Data) {
        // no-op
    }
    
    func encrypt(_ data: Data) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Data {
        fatalError("This should not be called")
    }
    
    func encrypt(_ string: String) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> String {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int16) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int16 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int32) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int32 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int64) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int64 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ double: Double) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Double {
        fatalError("This should not be called")
    }
    
    func encrypt(_ float: Float) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Float {
        fatalError("This should not be called")
    }
    
    func encrypt(_ date: Date) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Date {
        fatalError("This should not be called")
    }
    
    func encrypt(_ bool: Bool) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Bool {
        fatalError("This should not be called")
    }
}
