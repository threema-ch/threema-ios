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

import Foundation

extension Data {
    
    public enum LittleEndianConversionError: Error {
        case notEnoughBytes
    }
    
    /// Convert data into a FixedWidthInteger
    /// - Parameter fromByteOffset: Start of byte to read from data. Default is `0`
    /// - Returns: `FixedWithInteger` starting at `fromByteOffset` read as little endian
    /// - Throws: `LittleEndianConversionError`
    public func littleEndian<T: FixedWidthInteger>(fromByteOffset: Int = 0) throws -> T {
        guard count >= (fromByteOffset + MemoryLayout<T>.size) else {
            throw LittleEndianConversionError.notEnoughBytes
        }
        
        // Inspired by https://forums.swift.org/t/how-to-read-uint32-from-a-data/59431/4
        let loadedFixedWidthInteger = withUnsafeBytes {
            $0.load(fromByteOffset: fromByteOffset, as: T.self)
        }
        
        return T(littleEndian: loadedFixedWidthInteger)
    }
    
    /// Convert data into a FixedWidthInteger. If the data is too small we pad it with `0`s.
    ///
    /// In general you should prefer `littleEndian<T: FixedWidthInteger>(fromByteOffset:)` over this function.
    ///
    /// - Parameter fromByteOffset: Start of byte to read from data. Default `0`
    /// - Returns: `FixedWithInteger` starting at `fromByteOffset` read as little endian and padded with `0`s if needed
    public func paddedLittleEndian<T: FixedWidthInteger>(fromByteOffset: Data.Index = 0) -> T {
        let maxOffset = fromByteOffset + MemoryLayout<T>.size
        let actualMaxOffset = maxOffset <= count ? maxOffset : count
        
        // Inspired by https://developer.apple.com/forums/thread/652469?answerId=617848022#617848022
        let loadedFixedWidthInteger = subdata(in: fromByteOffset..<actualMaxOffset)
            .reversed()
            .reduce(0) { soFar, new in
                (soFar << 8) | T(new)
            }
        
        return T(littleEndian: loadedFixedWidthInteger)
    }
}
