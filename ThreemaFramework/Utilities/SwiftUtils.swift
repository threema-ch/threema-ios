//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

public enum SwiftUtils {
    
    /// Use this class for new utils. Rewrite old Objective C utils if needed
    
    /// Returns a pseudorandom string
    /// - Parameter length: the length of the returned String
    /// - Returns: A pseudorandom string of the given length
    public static func pseudoRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    /// Returns a pseudorandom string, letters only in upper case.
    /// - Parameters:
    ///    - length: The length of the returned String
    ///    - exclude: Exclude characters for calculation
    /// - Returns: A pseudorandom string of the given length
    public static func pseudoRandomStringUpperCaseOnly(length: Int, exclude: [Character]?) -> String {
        var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        if let exclude {
            letters.removeAll { character in
                exclude.contains(character)
            }
        }

        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
