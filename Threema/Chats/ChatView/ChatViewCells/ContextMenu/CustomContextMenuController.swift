import Foundation

final class CustomContextMenuController: CustomContextMenuViewControllerDelegate {
    
    private var viewController: CustomContextMenuViewController?
    private weak var chatViewController: ChatViewController?
    private weak var cell: ChatViewBaseTableViewCell?
    
    public func presentContextMenu(
        chatViewController: ChatViewController,
        for cell: ChatViewBaseTableViewCell,
        on parent: UIView,
        with snapshot: UIView,
        snapshotBounds: CGRect,
        chatViewBounds: CGRect,
        isOwnMessage: Bool,
        showEmojiPicker: Bool,
        reactionsManager: ReactionsManager?,
        actions: [ChatViewMessageActionsProvider.MessageActionsSection]?
    ) {
        guard let window = parent.window else {
            return
        }
        
        let viewController = CustomContextMenuViewController(
            delegate: self,
            snapshot: snapshot,
            snapshotBounds: snapshotBounds,
            chatViewBounds: chatViewBounds,
            isOwnMessage: isOwnMessage,
            showEmojiPicker: showEmojiPicker,
            reactionsManager: reactionsManager,
            actions: actions
        )
        
        self.chatViewController = chatViewController
        self.viewController = viewController
        window.addSubview(viewController.view)
        viewController.view.frame = window.bounds
        
        self.cell = cell
        cell.contentView.isHidden = true
    }
        
    func dismiss(completion: (() -> Void)? = nil) {
        if let viewController {
            viewController.dismiss { [weak self] in
                self?.chatViewController?.willHideContextMenu(animator: nil)
                self?.cell?.contentView.isHidden = false
                self?.cell = nil
                completion?()
            }
        }
        else {
            chatViewController?.willHideContextMenu(animator: nil)
            cell?.contentView.isHidden = false
            cell = nil
            completion?()
        }
    }
}
