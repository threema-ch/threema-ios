//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

/// When we ditch `objc` move this into the `GroupDetails` name space and remove `Int`
@objc enum GroupDetailsDisplayMode: Int {
    case `default`
    case conversation
}

enum GroupDetails {
    enum Section {
        case members
        case creator
        case contentActions
        case notifications
        case groupActions
        case destructiveGroupActions
        case wallpaper
        case debugInfo
    }
    
    enum Row: Hashable {
        // General
        case action(_ action: Details.Action)
        
        // Group members
        case meContact
        // Set ifSelfMember false to disable contacts when current user is not member of this group
        case contact(_ contact: Contact, isSelfMember: Bool = true)
        case unknownContact
        case membersAction(_ action: Details.Action)
        
        // `inMembers` is a workaround to use the same creator in two sections of the table view and
        // make it unique to the diffable data source. This should be removed when we remove the
        // creator section. (IOS-2045)
        case meCreator(left: Bool = false, inMembers: Bool = false)
        case contactCreator(_ contact: Contact, left: Bool = false, inMembers: Bool = false)
        case unknownContactCreator(left: Bool = false, inMembers: Bool = false)
        
        // Notifications
        case doNotDisturb(action: Details.Action, group: Group)
        case booleanAction(_ action: Details.BooleanAction)
        
        // Wallpaper
        case wallpaper(action: Details.Action, isDefault: Bool)
        
        // Debug
        case fsDebugMember(contact: Contact, sessionInfo: String)
    }
}
