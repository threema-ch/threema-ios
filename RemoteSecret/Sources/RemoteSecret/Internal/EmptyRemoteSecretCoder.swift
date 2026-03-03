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

struct EmptyRemoteSecretCoder: RemoteSecretCodable {
    func decode(_ data: Data) -> String {
        fatalError("This should not be called")
    }
    
    func decode<T>(_ data: Data) -> T where T: FixedWidthInteger {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Double {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Float {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Date {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Bool {
        fatalError("This should not be called")
    }
    
    func encode(_ string: String) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ double: Double) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ float: Float) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ date: Date) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ bool: Bool) -> Data {
        fatalError("This should not be called")
    }
}
