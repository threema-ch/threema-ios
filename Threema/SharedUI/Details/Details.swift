//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

/// When we remove `objc` move this into the `Details` name space and remove `Int`
@objc enum DetailsDisplayStyle: Int {
    case `default`
    case preview
}

/// Delegate for details
///
/// When we remove `objc` check if we can move this into the `Details` name space
@objc protocol DetailsDelegate: AnyObject {
    /// Called when the details view controller did disappear
    func detailsDidDisappear()
    
    /// Show a chat search in the delegate
    func showChatSearch()
    
    /// Called before the detail view deletes messages
    /// - Parameter objectIDs: Object IDs of messages that will be deleted
    func willDeleteMessages(with objectIDs: [NSManagedObjectID])
    
    /// Called before the detail view will delete all messages in this conversation
    func willDeleteAllMessages()
}

enum Details {

    struct Action: Hashable {
        typealias Action = (UIView) -> Void
                
        let title: String
        
        let imageName: String?
        
        let destructive: Bool
        
        let disabled: Bool
        
        let run: Action
        
        init(
            title: String,
            imageName: String? = nil,
            destructive: Bool = false,
            disabled: Bool = false,
            action: @escaping Action
        ) {
            self.title = title
            self.imageName = imageName
            self.destructive = destructive
            self.disabled = disabled
            self.run = action
        }
        
        // Equatable
        static func == (lhs: Details.Action, rhs: Details.Action) -> Bool {
            lhs.title == rhs.title
                && lhs.imageName == rhs.imageName
                && lhs.destructive == rhs.destructive
        }
        
        // Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(imageName)
            hasher.combine(destructive)
        }
    }
    
    struct BooleanAction: Hashable {
        typealias BoolProvider = () -> Bool
        typealias Action = (Bool) -> Void
                
        let title: String
        let currentBool: BoolProvider
        
        let destructive: Bool
        let disabled: Bool
        
        let run: Action
        
        init(
            title: String,
            destructive: Bool = false,
            disabled: Bool = false,
            boolProvider: @escaping BoolProvider,
            action: @escaping Action
        ) {
            self.title = title
            self.destructive = destructive
            self.disabled = disabled
            self.currentBool = boolProvider
            self.run = action
        }
        
        // Equatable
        static func == (lhs: Details.BooleanAction, rhs: Details.BooleanAction) -> Bool {
            lhs.title == rhs.title
                && lhs.destructive == rhs.destructive
        }
        
        // Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(destructive)
        }
    }
}
