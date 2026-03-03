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

enum SelectContactListDisplayMode {
    
    case contact(data: [Contact])
    case group(GroupAction)
    case distributionList(DistributionListAction)
    
    enum GroupAction {
        case create(data: EditData)
        case edit(data: EditData)
        case clone(original: Group)
    }
    
    enum DistributionListAction {
        case create(data: EditData)
        case edit(data: EditData)
    }
}

// MARK: - Helpers

extension SelectContactListDisplayMode {
    var isEdit: Bool {
        switch self {
        case .contact:
            true
        case .group(.edit), .distributionList(.edit):
            true
        default:
            false
        }
    }
    
    var editData: EditData? {
        switch self {
        case .contact:
            nil

        case let .group(action):
            switch action {
            case let .create(data), let .edit(data):
                data
            default:
                nil
            }
            
        case let .distributionList(action):
            switch action {
            case let .create(data), let .edit(data):
                data
            }
        }
    }
    
    var selectedContacts: [Contact] {
        switch self {
        case let .contact(data):
            data

        case let .group(action):
            switch action {
            case let .create(data):
                data.contacts
            case let .edit(data):
                data.contacts
            case let .clone(group):
                group.sortedMembers.compactMap {
                    if case let .contact(contact) = $0 {
                        contact
                    }
                    else {
                        nil
                    }
                }
            }
            
        case let .distributionList(action):
            switch action {
            case let .create(data):
                data.contacts
            case let .edit(data):
                data.contacts
            }
        }
    }
    
    var countLabelKind: ContactCollectionCountLabel.Kind {
        switch self {
        case .contact:
            .none
        case .group:
            .group
        case .distributionList:
            .distributionList
        }
    }
    
    var title: String {
        switch self {
        case .contact:
            #localize("add_recipient")
        case .group:
            #localize("group_add_members_button")
        case .distributionList:
            #localize("add_recipient")
        }
    }
}
