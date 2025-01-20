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

import Foundation

struct Address {
    let ip: String
    let port: UInt32
    
    var protocolVersion: IPAdressProtocolVersion {
        // Regular expression to match IPv4 address
        guard let ipv4Regex = try? NSRegularExpression(pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") else {
            return .unknown
        }
        
        // Regular expression to match IPv6 address
        guard let ipv6Regex = try? NSRegularExpression(pattern: "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$") else {
            return .unknown
        }
        
        if ipv4Regex.firstMatch(in: ip, options: [], range: NSRange(location: 0, length: ip.utf16.count)) != nil {
            return .ipv4
        }
        else if ipv6Regex
            .firstMatch(in: ip, options: [], range: NSRange(location: 0, length: ip.utf16.count)) != nil {
            return .ipv6
        }
        else {
            return .unknown
        }
    }
}
