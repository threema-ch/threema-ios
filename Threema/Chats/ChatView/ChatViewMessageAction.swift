//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

protocol ChatViewMessageAction: ThemedCodeTableViewCell {
    
    /// Creates an array of ChatViewMessageActionProvider.MessageAction used to create context menus and accessibility
    /// custom actions
    /// - Returns: Tuple containing two Arrays of ChatViewMessageActionProvider.MessageAction
    func messageActions()
        -> (
            primaryActions: [ChatViewMessageActionProvider.MessageAction],
            generalActions: [ChatViewMessageActionProvider.MessageAction]
        )?
    
    /// Creates an UIContextMenuConfiguration to be used in a ContextMenu
    /// - Parameter indexPath: Index path of cell UIContextMenuConfiguration is built for
    /// - Returns: descriptionUIContextMenuConfiguration
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration?
    
    /// Creates an array of UIAccessibilityCustomActions
    /// - Returns: Array of UIAccessibilityCustomAction
    func buildAccessibilityCustomActions() -> [UIAccessibilityCustomAction]?
}

extension ChatViewMessageAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let (primaryActions, generalActions) = messageActions() else {
            return nil
        }
        
        if #available(iOS 16.0, *) {
            let primaryMenuActions = primaryActions.map(\.contextMenuAction)
            let primaryMenu = UIMenu(options: .displayInline, children: primaryMenuActions)
            primaryMenu.preferredElementSize = .small
            
            let generalMenuActions = generalActions.map(\.contextMenuAction)
            let generalMenu = UIMenu(options: .displayInline, children: generalMenuActions)

            let completeMenu = UIMenu(children: [primaryMenu, generalMenu])
            
            return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
                completeMenu
            }
        }
        else {
            var allActions = primaryActions.map(\.contextMenuAction)
            allActions.append(contentsOf: generalActions.map(\.contextMenuAction))
            let menu = UIMenu(children: allActions)
            
            return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
                menu
            }
        }
    }
    
    func buildAccessibilityCustomActions() -> [UIAccessibilityCustomAction]? {
        guard let (primaryActions, generalActions) = messageActions() else {
            return nil
        }
        
        var allActions = primaryActions
        allActions.append(contentsOf: generalActions)
        return allActions.map(\.accessibilityAction)
    }
}
