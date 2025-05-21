//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaMacros

enum ContactListAddItem: MenuItem {
    case contacts
    case groups
    case distributionLists

    var id: Self { self }
    
    var label: String {
        switch self {
        case .contacts:
            #localize("contactList_add_contact")
        case .groups:
            #localize("contactList_add_group")
        case .distributionLists:
            #localize("distribution_list_create")
        }
    }
    
    var icon: ThreemaImageResource {
        switch self {
        case .contacts:
            .systemImage("person.badge.plus")
        case .groups:
            .bundleImage("threema.person.3.badge.plus")
        case .distributionLists:
            .bundleImage("threema.megaphone.badge.plus")
        }
    }
    
    var enabled: Bool {
        let mdm = MDMSetup(setup: false)
        return switch self {
        case .contacts:
            !(mdm?.disableAddContact() ?? true)
        case .groups:
            !(mdm?.disableCreateGroup() ?? false)
        case .distributionLists:
            ThreemaEnvironment.distributionListsActive
        }
    }
    
    var accessibilityLabel: String? {
        nil
    }
}
