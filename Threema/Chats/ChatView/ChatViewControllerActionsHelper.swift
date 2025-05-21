//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import UIKit

/// Allows the new ChatViewController to interact with legacy actions implemented for the old ChatViewController
/// Not all methods must be properly implemented as long as one has made sure that they are never actually called.
@objc class ChatViewControllerActionsHelper: NSObject {
    private weak var chatViewController: ChatViewController?
    public weak var conversation: ConversationEntity?
    
    var currentLegacyAction: SendMediaAction?
    
    init(conversation: ConversationEntity, chatViewController: ChatViewController) {
        self.conversation = conversation
        self.chatViewController = chatViewController
    }
}

// MARK: - ChatViewControllerActionsProtocol

extension ChatViewControllerActionsHelper: ChatViewControllerActionsProtocol {
    var chatContent: UITableView? {
        get {
            let message = "\(#function) should not be called"
            assertionFailure(message)
            DDLogError("\(message)")
            return nil
        }
        set(chatContent) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    var navigationController: UINavigationController? {
        get {
            chatViewController?.navigationController
        }
        set(navigationController) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    var isEditing: Bool {
        get {
            chatViewController?.isEditing ?? false
        }
        set(editing) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    func setEditing(_ editing: Bool, animated: Bool) {
        let message = "\(#function) should not be called"
        assertionFailure(message)
        DDLogError("\(message)")
    }
    
    var view: UIView? {
        get {
            chatViewController?.view
        }
        set(view) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    var presentedViewController: UIViewController? {
        get {
            chatViewController?.presentedViewController
        }
        set(presentedViewController) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    var storyboard: UIStoryboard? {
        get {
            let message = "\(#function) should not be called"
            assertionFailure(message)
            DDLogError("\(message)")
            return nil
        }
        set(storyboard) {
            fatalError("\(#function) should not be called.")
        }
    }
    
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        guard let chatViewController else {
            fatalError("\(#function) should not be called.")
        }
        chatViewController.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    func dismissViewController(animated flag: Bool, completion: (() -> Void)?) {
        guard let chatViewController else {
            fatalError("\(#function) should not be called.")
        }
        chatViewController.dismiss(animated: flag, completion: completion)
    }
    
    func updateConversation() {
        let message = "\(#function) should not be called"
        assertionFailure(message)
        DDLogError("\(message)")
    }
    
    func updateConversationLastMessage() {
        let message = "\(#function) should not be called"
        assertionFailure(message)
        DDLogError("\(message)")
    }
    
    func object(at indexPath: IndexPath) -> Any! {
        fatalError("\(#function) should not be called.")
    }
    
    func doResignFirstResponder() {
        chatViewController?.chatBarCoordinator.resignFirstResponder()
    }
}
