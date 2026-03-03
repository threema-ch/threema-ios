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

struct KeychainItemData: Equatable {
    let accessibility: CFString?
    let label: String?
    let account: String?
    let password: Data?
    let generic: Data?
    let service: String?
    
    init(
        accessibility: CFString?,
        label: String?,
        account: String?,
        password: Data?,
        generic: Data?,
        service: String?
    ) {
        self.accessibility = accessibility
        self.label = label
        self.account = account
        self.password = password
        self.generic = generic
        self.service = service
    }
    
    static func == (
        lhs: KeychainItemData,
        rhs: KeychainItemData
    ) -> Bool {
        lhs.accessibility == rhs.accessibility &&
            lhs.label == rhs.label &&
            lhs.account == rhs.account &&
            lhs.password == rhs.password &&
            lhs.generic == rhs.generic &&
            lhs.service == rhs.service
    }
}
