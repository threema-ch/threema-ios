//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
import ThreemaFramework
import UIKit

protocol ChatViewTableViewCellDelegateProtocol: AnyObject {
    var chatViewHasCustomBackground: Bool { get }
    
    func swipeMessageTableViewCell(
        swipeMessageTableViewCell: ChatViewBaseTableViewCell,
        recognizer: UIPanGestureRecognizer
    )
    
    func configure(swipeGestureRecognizer: UIPanGestureRecognizer)

    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?)
    func showQuoteView(message: QuoteMessage)
    func startMultiselect()
    
    func quoteTapped(on quotedMessageID: Data)
    func show(identity: String)
    func clearCellHeightCache(for objectID: NSManagedObjectID)
    func showDetails(for messageID: NSManagedObjectID)
    
    func didSelectText(in textView: MessageTextView?)
    
    var currentSearchText: String? { get }
}

extension ChatViewTableViewCellDelegateProtocol {
    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?) {
        didTap(message: message, in: cell, customDefaultAction: nil)
    }
}

/// Implements ChatViewTableViewCellDelegateProtocol to allow communication between cells and ChatViewController instances
final class ChatViewTableViewCellDelegate: NSObject, ChatViewTableViewCellDelegateProtocol {
    // MARK: - Private Properties
    
    private weak var tableView: UITableView?
    
    private weak var chatViewController: ChatViewController?
    private lazy var animationProxy = ChatViewMessageRightToLeftTransitionProxy(
        delegate: self,
        navigationController: chatViewController?.navigationController
    )
    private let cellHeightCache = CellHeightCache()
    private let entityManager: EntityManager
    
    private lazy var chatViewDefaultTapActionProvider = ChatViewDefaultMessageTapActionProvider(
        chatViewController: chatViewController,
        entityManager: entityManager
    )
    
    private lazy var chatViewBackgroundImageProvider = ChatViewBackgroundImageProvider()
    
    // MARK: Internal Properties

    var chatViewHasCustomBackground: Bool {
        chatViewBackgroundImageProvider.hasCustomBackground
    }
    
    // MARK: - Lifecycle

    init(chatViewController: ChatViewController, tableView: UITableView, entityManager: EntityManager) {
        self.chatViewController = chatViewController
        self.tableView = tableView
        self.entityManager = entityManager
    }
    
    // MARK: - Swipe Interactions
    
    func swipeMessageTableViewCell(
        swipeMessageTableViewCell: ChatViewBaseTableViewCell,
        recognizer: UIPanGestureRecognizer
    ) {
        guard let tableView = tableView else {
            DDLogError("tableView should not be nil")
            return
        }
        
        guard let recognizersView = recognizer.view else {
            DDLogError("Recognizer does not have an associated view.")
            return
        }
        
        let percent = -recognizer.translation(in: recognizersView).x / recognizersView.bounds.size.width
        let alpha = 1 - percent
        for cell in tableView.visibleCells {
            if cell != swipeMessageTableViewCell {
                cell.alpha = alpha > 0.5 ? alpha : 0.5
            }
        }
        
        let messageDetailViewController = ChatViewMessageDetailView(
            messageID: swipeMessageTableViewCell
                .messageObjectID
        )
        animationProxy.handleSwipeLeft(recognizer, toViewController: messageDetailViewController) {
            for cell in tableView.visibleCells {
                cell.alpha = 1.0
            }
        }
    }
    
    func configure(swipeGestureRecognizer: UIPanGestureRecognizer) {
        if let interactivePopGestureRecognizer = chatViewController?.navigationController?
            .interactivePopGestureRecognizer {
            interactivePopGestureRecognizer.canPrevent(swipeGestureRecognizer)
            swipeGestureRecognizer.require(toFail: interactivePopGestureRecognizer)
        }
        
        if let tableView = tableView {
            swipeGestureRecognizer.canPrevent(tableView.panGestureRecognizer)
            tableView.panGestureRecognizer.require(toFail: swipeGestureRecognizer)
        }
    }
    
    // MARK: - Tap Interactions
    
    func show(identity: String) {
        if let contact = BusinessInjector().entityManager.entityFetcher.contact(for: identity) {
            let detailsViewController = SingleDetailsViewController(for: contact)
            let navigationController = ThemedNavigationController(rootViewController: detailsViewController)
            navigationController.modalPresentationStyle = .formSheet
            
            chatViewController?.present(navigationController, animated: true)
        }
        else if identity == BusinessInjector().myIdentityStore.identity {
            // TODO: IOS-2927 Refactor `MeContactDetailsViewController` to allow removing `MainStoryboard`
            let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "meContactDetailsViewController")
            
            let navigationController = ModalNavigationController(rootViewController: vc)
            navigationController.modalPresentationStyle = .formSheet
            navigationController.showDoneButton = true
            
            chatViewController?.present(navigationController, animated: true)
        }
        else {
            DDLogError("Can't find contact for tapped mention")
        }
    }

    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?) {
        
        guard let message = message,
              let cell = cell else {
            DDLogWarn("Tapped chat cell that does not exist or that has no message attached")
            return
        }
        
        // Highlight cell
        cell.blinkCell(
            duration: ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightedDurationTap,
            feedback: false,
            completeCell: false
        )
        
        // Run Action
        chatViewDefaultTapActionProvider.run(for: message, customDefaultAction: customDefaultAction)
    }
    
    func showQuoteView(message: QuoteMessage) {
        chatViewController?.chatBarCoordinator.showQuoteView(for: message)
    }
    
    func quoteTapped(on quotedMessageID: Data) {
        chatViewController?.jump(to: quotedMessageID, animated: true, highlight: true)
    }
    
    // MARK: - Multi-Select

    func startMultiselect() {
        chatViewController?.startMultiselect()
    }
    
    // MARK: - CellHeightCache
    
    func clearCellHeightCache(for objectID: NSManagedObjectID) {
        cellHeightCache.clearCellHeightCache(for: objectID)
    }
    
    func showDetails(for messageID: NSManagedObjectID) {
        let detailsVC = ChatViewMessageDetailView(messageID: messageID)
        chatViewController?.navigationController?.pushViewController(detailsVC, animated: true)
    }
    
    // MARK: - Text selection
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewController?.selectedTextView = textView
    }
    
    // MARK: - Search Highlighting
    
    var currentSearchText: String?
}
