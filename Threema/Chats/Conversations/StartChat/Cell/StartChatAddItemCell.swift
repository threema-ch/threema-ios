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

import ThreemaMacros

final class StartChatAddItemCell: UITableViewCell {
    
    // MARK: - Type
    
    enum AddItemKind {
        case contact
        case group
        case distributionList
        
        var label: String {
            switch self {
            case .contact:
                #localize("contactList_add_contact")
            case .group:
                #localize("contactList_add_group")
            case .distributionList:
                #localize("distribution_list_create")
            }
        }
        
        var icon: ThreemaImageResource {
            switch self {
            case .contact:
                .systemImage("person.badge.plus")
            case .group:
                .bundleImage("threema.person.3.badge.plus")
            case .distributionList:
                .bundleImage("threema.megaphone.badge.plus")
            }
        }
        
        var enabled: Bool {
            let mdm = MDMSetup()
            return switch self {
            case .contact:
                !(mdm?.disableAddContact() ?? true)
            case .group:
                !(mdm?.disableCreateGroup() ?? false)
            case .distributionList:
                ThreemaEnvironment.distributionListsActive
            }
        }
    }
    
    // MARK: - Configure

    func configure(with kind: AddItemKind) {
        let isEnabled = kind.enabled
        var content = defaultContentConfiguration()
        content.image = kind.icon.uiImage.withConfiguration(UIImage.SymbolConfiguration(scale: .medium))
        content.text = kind.label
        content.textProperties.color = isEnabled ? .tintColor : .secondaryLabel
        content.imageProperties.tintColor = isEnabled ? .tintColor : .secondaryLabel
        
        contentConfiguration = content
        isUserInteractionEnabled = isEnabled
    }
}

// MARK: - Reusable

extension StartChatAddItemCell: Reusable { }
