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

protocol RemoteSecretEncodable {
    // MARK: String
    
    func encode(_ string: String) -> Data
    
    // MARK: FixedWithInteger
    
    func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data
    
    // MARK: Double
    
    func encode(_ double: Double) -> Data
    
    // MARK: Float
    
    func encode(_ float: Float) -> Data
    
    // MARK: Date
    
    func encode(_ date: Date) -> Data
    
    // MARK: Bool
    
    func encode(_ bool: Bool) -> Data
}

protocol RemoteSecretDecodable {
    // MARK: String
    
    func decode(_ data: Data) -> String
    
    // MARK: FixedWithInteger
    
    func decode<T: FixedWidthInteger>(_ data: Data) -> T
    
    // MARK: Double
    
    func decode(_ data: Data) -> Double
    
    // MARK: Float
    
    func decode(_ data: Data) -> Float
    
    // MARK: Date
    
    func decode(_ data: Data) -> Date
    
    // MARK: Bool
    
    func decode(_ data: Data) -> Bool
}

typealias RemoteSecretCodable = RemoteSecretEncodable & RemoteSecretDecodable

typealias SendableRemoteSecretCodable = RemoteSecretCodable & Sendable
