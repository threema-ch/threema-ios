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

import SwiftUI
import ThreemaFramework
import ThreemaMacros

typealias ContactListFilterMenuView = UIHostingController<MenuItemSelection<ContactListFilterItem>>

extension ContactListFilterMenuView {
    convenience init(_ didSelect: @escaping (ContactListFilterItem) -> Void) {
        self.init(rootView: MenuItemSelection(didSelect: didSelect))
        view.backgroundColor = .clear
    }
}

enum ContactListFilterItem: Int {
    case contacts = 0
    case groups = 1
    case distributionLists = 2
}

// MARK: - MenuItem

extension ContactListFilterItem: MenuItem {
    var id: Self { self }
    
    var label: String {
        switch self {
        case .contacts:
            #localize("segmentcontrol_contacts")
        case .groups:
            #localize("segmentcontrol_groups")
        case .distributionLists:
            #localize("segmentcontrol_distribution_list")
        }
    }
    
    var icon: ThreemaImageResource {
        switch self {
        case .contacts:
            .systemImage("person.2.fill")
        case .groups:
            .systemImage("person.3.fill")
        case .distributionLists:
            .systemImage("megaphone.fill")
        }
    }
    
    var enabled: Bool {
        switch self {
        case .contacts, .groups:
            true
        case .distributionLists:
            ThreemaEnvironment.distributionListsActive
        }
    }
    
    var accessibilityLabel: String? {
        switch self {
        case .contacts:
            #localize("segmentcontrol_contacts")
        case .groups:
            #localize("segmentcontrol_groups")
        case .distributionLists:
            #localize("segmentcontrol_distribution_list")
        }
    }
}
