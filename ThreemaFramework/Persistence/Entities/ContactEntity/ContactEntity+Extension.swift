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

extension ContactEntity {
    @objc public var isEchoEcho: Bool {
        identity == "ECHOECHO"
    }
    
    @objc public var isGatewayID: Bool {
        identity.hasPrefix("*")
    }
    
    @objc public func updateSortInitial(sortOrderFirstName: Bool) {
        if isGatewayID {
            sortInitial = "*"
            sortIndex = NSNumber(value: ThreemaLocalizedIndexedCollation.sectionTitles.count - 1)
        }
        else {
            // find the first keyPath where the length is greater than 0, fallback to identity
            var string = identity
            
            if !(firstName?.isEmpty ?? true) || !(lastName?.isEmpty ?? true) {
                if sortOrderFirstName {
                    if let firstName, !firstName.isEmpty {
                        string = firstName
                    }
                    else if let lastName, !lastName.isEmpty {
                        string = lastName
                    }
                }
                else {
                    if let lastName, !lastName.isEmpty {
                        string = lastName
                    }
                    else if let firstName, !firstName.isEmpty {
                        string = firstName
                    }
                }
            }
            else if let publicNickname, !publicNickname.isEmpty {
                string = publicNickname
            }

            let idx = ThreemaLocalizedIndexedCollation.section(for: string)
            let sortInitial = ThreemaLocalizedIndexedCollation.sectionTitles[idx]
            let sortIndex = NSNumber(value: idx)

            if self.sortInitial != sortInitial {
                self.sortInitial = sortInitial
            }
            if self.sortIndex != sortIndex {
                self.sortIndex = sortIndex
            }
        }
    }
}
