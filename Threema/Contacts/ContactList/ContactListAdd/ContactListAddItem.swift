//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaFramework

enum ContactListAddItem: MenuItem, CaseIterable {
    case contacts, groups, distributionLists
    
    var id: Self { self }
    
    var label: String {
        switch self {
        case .contacts:
            "contactList_add_contact".localized
        case .groups:
            "contactList_add_group".localized
        case .distributionLists:
            "distribution_list_create".localized
        }
    }
    
    var icon: ThreemaImageResource {
        switch self {
        case .contacts:
            .systemImage("person.fill.badge.plus")
        case .groups:
            .bundleImage("threema.person.3.fill.badge.plus")
        case .distributionLists:
            .bundleImage("threema.megaphone.fill.badge.plus")
        }
    }
}
