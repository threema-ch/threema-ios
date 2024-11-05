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

import Foundation

public class DHSessionID: CustomStringConvertible, Equatable, Comparable {
    static let dhSessionIDLength = 16
    let value: Data
    
    init() {
        self.value = BytesUtility.generateRandomBytes(length: DHSessionID.dhSessionIDLength)!
    }
    
    init(value: Data) throws {
        if value.count != DHSessionID.dhSessionIDLength {
            throw ForwardSecurityError.invalidSessionIDLength
        }
        self.value = value
    }
    
    public var description: String {
        BytesUtility.toHexString(data: value)
    }
    
    public static func == (lhs: DHSessionID, rhs: DHSessionID) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: DHSessionID, rhs: DHSessionID) -> Bool {
        let alhs = [UInt8](lhs.value)
        let blhs = [UInt8](rhs.value)
        for i in 0..<alhs.count {
            if alhs[i] < blhs[i] {
                return true
            }
            else if alhs[i] > blhs[i] {
                return false
            }
        }
        return false
    }
}
