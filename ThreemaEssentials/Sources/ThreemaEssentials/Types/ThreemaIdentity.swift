//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import Foundation

public struct ThreemaIdentity: Equatable, Hashable, CustomStringConvertible, Sendable, Codable {
    private enum CodingKeys: String, CodingKey {
        case string
    }
    
    /// Expected length of string representing a `ThreemaIdentity`
    public static let stringLength = 8

    public let string: String

    public init(_ string: String) {
        if string.count != ThreemaIdentity.stringLength {
            assertionFailure("Tried to create a ThreemaIdentity with length of \(string.count)")
            DDLogError("Tried to create a ThreemaIdentity with length of \(string.count)")
        }

        self.string = string.uppercased()
    }

    public var description: String {
        string
    }
    
    public var isGatewayID: Bool {
        string.hasPrefix("*")
    }
}
