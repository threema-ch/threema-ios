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

protocol ChatViewMessageActions: ThemedCodeTableViewCell {
    
    /// Creates various message actions sections used to create context menus and accessibility custom actions
    /// - Returns: An array of sections with actions
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]?
}

extension ChatViewMessageActions {
    
    /// Creates an `UIContextMenuConfiguration` to be used in a ContextMenu
    /// - Parameter indexPath: Index path of cell `UIContextMenuConfiguration` is built for
    /// - Returns: `UIContextMenuConfiguration` for cell at index path
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let actionsSections = messageActionsSections() else {
            return nil
        }
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            UIMenu(children: actionsSections.map(\.contextMenu))
        }
    }
    
    /// Creates an array of `UIAccessibilityCustomActions`
    /// - Returns: Array of `UIAccessibilityCustomAction`
    func buildAccessibilityCustomActions() -> [UIAccessibilityCustomAction]? {
        guard let actionsSections = messageActionsSections() else {
            return nil
        }
        
        return actionsSections.flatMap(\.accessibilityActions)
    }
}
