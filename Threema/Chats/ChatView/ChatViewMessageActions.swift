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
    /// - Parameter reactionsManager: `ReactionsManager` that provides the actions for reactions
    /// - Returns: Array of `UIAccessibilityCustomAction`
    func buildAccessibilityCustomActions(reactionsManager: ReactionsManager?) -> [UIAccessibilityCustomAction]? {
        guard isUserInteractionEnabled, let actionsSections = messageActionsSections() else {
            return nil
        }
        
        var baseActions = actionsSections.flatMap(\.accessibilityActions)
        
        if let reactionsManager {
            baseActions.append(contentsOf: reactionsManager.accessibilityActions())
        }
        
        return baseActions
    }
}
