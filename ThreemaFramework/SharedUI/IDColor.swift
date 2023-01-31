//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import CocoaLumberjackSwift
import CryptoKit
import Foundation

struct IDColor {
    
    /// Get the ID Color for the passed data
    /// - Parameter data: Data to get ID color for. We assume that is quite small.
    /// - Returns: Dynamic ID Color for `data`
    static func forData(_ data: Data) -> UIColor {
        guard let firstByte = firstSHA256Byte(for: data),
              !UIAccessibility.isDarkerSystemColorsEnabled else {
            // We don't expect this to ever happen
            DDLogWarn("Unable to get first byte for ID Color")
            return Colors.primary
        }
        
        return Colors.IDColor.forByte(firstByte)
    }
    
    /// Cache first byte calculation
    ///
    /// As it is independent of the colors it doesn't need to be reset at any point.
    private static var cache = [Data: UInt8]()
    
    private static func firstSHA256Byte(for data: Data) -> UInt8? {
        if let firstByte = cache[data] {
            return firstByte
        }
        
        let idHash = SHA256.hash(data: data)
        
        // Thats the "easiest" way we found to get a first byte of the digest
        // Another way would be to use `prefix()` with a `map()` to `UInt8` and then take the first element.
        // (i.e. `idHash.prefix(1).map({ $0 as UInt8 }).first`)
        var iterator = idHash.makeIterator()
        let firstByte = iterator.next()
        
        cache[data] = firstByte
        return firstByte
    }
}
