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

/// Sequence number as defined in various Threema protocol specifications
///
/// Initialized at 0 so the first `next()` number is 1
public class SequenceNumber<T: UnsignedInteger> {
    
    private var current: T = 0
    
    /// Create a new sequence number
    public init() {
        // no-op
    }
    
    /// Get next sequence number
    ///
    /// The first number will be 1.
    ///
    /// - Returns: Next sequence number
    public func next() -> T {
        // This will crash if the sequence number overflows
        current += 1
        return current
    }
}
