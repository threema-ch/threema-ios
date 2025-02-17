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

import Foundation

class CustomContextMenuController: CustomContextMenuViewControllerDelegate {
    
    private var viewController: CustomContextMenuViewController?
    private weak var chatViewController: ChatViewController?
    
    public func presentContextMenu(
        chatViewController: ChatViewController,
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
    }
        
    func dismiss(completion: (() -> Void)? = nil) {
        if let viewController {
            viewController.dismiss { [weak self] in
                self?.chatViewController?.willHideContextMenu(animator: nil)
                completion?()
            }
        }
        else {
            chatViewController?.willHideContextMenu(animator: nil)
            completion?()
        }
    }
}
