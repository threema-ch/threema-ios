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
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ChatViewTableViewCellDelegateProtocol: AnyObject {
    func swipeMessageTableViewCell(
        swipeMessageTableViewCell: ChatViewBaseTableViewCell,
        recognizer: UIPanGestureRecognizer
    )
    
    func configure(swipeGestureRecognizer: UIPanGestureRecognizer)
    
    func playNextMessageIfPossible(from message: NSManagedObjectID)

    func didTap(message: BaseMessageEntity?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?)
    func didAccessibilityTapOnCell()
    
    func showQuoteView(message: QuoteMessage)
    func startMultiselect(with messageObjectID: NSManagedObjectID)
    
    func quoteTapped(on quotedMessageID: Data)
    func show(identity: String)
    func open(url: URL)
    func clearCellHeightCache(for objectID: NSManagedObjectID)
    func showDetails(for messageID: NSManagedObjectID)
    func willDeleteMessage(with objectID: NSManagedObjectID)
    func didDeleteMessages()
    func toggleMessageMarkerStar(message: BaseMessageEntity)
    func retryOrCancelSendingMessage(withID messageID: NSManagedObjectID, from sourceView: UIView)
    func editMessage(for messageObjectID: NSManagedObjectID)

    func didSelectText(in textView: MessageTextView?)
    
    func presentContextMenu(cell: ChatViewBaseTableViewCell)
    func dismissContextMenu(showEmojiPicker: Bool, for reactionsManager: ReactionsManager)
    func showReactionAlert(for result: ReactionsManager.ReactionSendingResult)
    func showExistingReactions(reactionsManager: ReactionsManager)
    func showReactionsView()
    
    var currentSearchText: String? { get }
    
    var cellInteractionEnabled: Bool { get }
    
    var chatViewHasCustomBackground: Bool { get }
    
    var chatViewIsGroupConversation: Bool { get }
    
    var chatViewIsDistributionListConversation: Bool { get }
}

extension ChatViewTableViewCellDelegateProtocol {
    func didTap(message: BaseMessageEntity?, in cell: ChatViewBaseTableViewCell?) {
        didTap(message: message, in: cell, customDefaultAction: nil)
    }
}

/// Implements ChatViewTableViewCellDelegateProtocol to allow communication between cells and ChatViewController
/// instances
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
    
    // MARK: - Lifecycle
    
    init(chatViewController: ChatViewController, tableView: UITableView, entityManager: EntityManager) {
        self.chatViewController = chatViewController
        self.tableView = tableView
        self.entityManager = entityManager
    }
    
    // MARK: - Wallpaper

    lazy var chatViewHasCustomBackground: Bool = {
        guard let objectID = chatViewController?.conversation.objectID else {
            return false
        }
        return !(
            WallpaperStore.shared.defaultIsEmptyWallpaper() || WallpaperStore.shared.defaultIsThreemaWallpaper()
        ) ||
            WallpaperStore.shared.hasCustomWallpaper(for: objectID)
    }()
    
    // MARK: - Group Conversation flag

    var chatViewIsGroupConversation: Bool {

        guard let conversation = chatViewController?.conversation else {
            return false
        }
        return conversation.isGroup
    }
    
    var chatViewIsDistributionListConversation: Bool {
        chatViewController?.conversation.distributionList != nil
    }
    
    // MARK: - Swipe Interactions
    
    func swipeMessageTableViewCell(
        swipeMessageTableViewCell: ChatViewBaseTableViewCell,
        recognizer: UIPanGestureRecognizer
    ) {
        guard let tableView else {
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
        
        guard let messageObjectID = swipeMessageTableViewCell.messageObjectID else {
            DDLogError("Message object ID should not be nil")
            return
        }
        
        let messageDetailViewController = ChatViewMessageDetailsViewController(
            messageManagedObjectID: messageObjectID
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
        
        if let tableView {
            swipeGestureRecognizer.canPrevent(tableView.panGestureRecognizer)
            tableView.panGestureRecognizer.require(toFail: swipeGestureRecognizer)
        }
    }
    
    // MARK: - Voice Message Play
    
    func playNextMessageIfPossible(from message: NSManagedObjectID) {
        chatViewController?.playNextMessageIfPossible(from: message)
    }
    
    // MARK: - Tap Interactions
    
    func show(identity: String) {
        if let contact = BusinessInjector.ui.entityManager.entityFetcher.contact(for: identity) {
            let detailsViewController = SingleDetailsViewController(for: Contact(contactEntity: contact))
            let navigationController = ThemedNavigationController(rootViewController: detailsViewController)
            navigationController.modalPresentationStyle = .formSheet
            
            chatViewController?.present(navigationController, animated: true)
        }
        else if identity == BusinessInjector.ui.myIdentityStore.identity {
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
    
    func open(url: URL) {
        guard let chatViewController else {
            return
        }
        
        IDNASafetyHelper.safeOpen(url: url, viewController: chatViewController)
    }
    
    func didTap(message: BaseMessageEntity?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?) {
        
        guard let message,
              let cell else {
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
    
    func didAccessibilityTapOnCell() {
        chatViewController?.didTapOnChatView()
    }
    
    func showQuoteView(message: QuoteMessage) {
        chatViewController?.chatBarCoordinator.showQuoteView(for: message)
    }
    
    func quoteTapped(on quotedMessageID: Data) {
        chatViewController?.jump(to: quotedMessageID, animated: true, highlight: true)
    }
    
    func willDeleteMessage(with objectID: NSManagedObjectID) {
        chatViewController?.willDeleteMessage(with: objectID)
    }
    
    func didDeleteMessages() {
        chatViewController?.didDeleteMessages()
    }
    
    // MARK: - Multi-Select
    
    func startMultiselect(with messageObjectID: NSManagedObjectID) {
        chatViewController?.startMultiselect(with: messageObjectID)
    }
    
    // MARK: - Message actions
    
    func toggleMessageMarkerStar(message: BaseMessageEntity) {
        entityManager.performAndWaitSave {
            if let markers = message.messageMarkers {
                markers.star = NSNumber(booleanLiteral: !markers.star.boolValue)
            }
            else {
                if let newMarker = self.entityManager.entityCreator.messageMarkersEntity() {
                    newMarker.star = NSNumber(booleanLiteral: true)
                    message.messageMarkers = newMarker
                }
                else {
                    fatalError()
                }
            }
        }
    }
    
    func editMessage(for messageObjectID: NSManagedObjectID) {
        entityManager.performAndWait {
            var text: String?

            let message = self.entityManager.entityFetcher.existingObject(with: messageObjectID) as? EditedMessage
            if let textMessage = message as? TextMessageEntity {
                text = textMessage.text
            }
            else if let fileMessage = message as? FileMessage {
                text = fileMessage.caption ?? ""
            }

            guard let message, let text else {
                return
            }

            self.chatViewController?.chatBarCoordinator.showEditedMessageView(for: message)
            self.chatViewController?.chatBarCoordinator.chatBar.setCurrentText(text)
        }
    }
    
    func presentContextMenu(cell: ChatViewBaseTableViewCell) {
        chatViewController?.presentContextMenu(cell: cell)
    }
    
    func dismissContextMenu(showEmojiPicker: Bool, for reactionsManager: ReactionsManager) {
        chatViewController?.dismissContextMenu(showEmojiPicker: showEmojiPicker, for: reactionsManager)
    }
    
    func showReactionAlert(for result: ReactionsManager.ReactionSendingResult) {
        chatViewController?.showReactionAlert(for: result)
    }
    
    func showExistingReactions(reactionsManager: ReactionsManager) {
        chatViewController?.showExistingReactions(reactionsManager: reactionsManager)
    }
    
    func showReactionsView() {
        chatViewController?.showReactionsView()
    }
    
    // MARK: - CellHeightCache
    
    func clearCellHeightCache(for objectID: NSManagedObjectID) {
        cellHeightCache.clearCellHeightCache(for: objectID)
    }
    
    func showDetails(for messageID: NSManagedObjectID) {
        let detailsVC = ChatViewMessageDetailsViewController(messageManagedObjectID: messageID)
        chatViewController?.navigationController?.pushViewController(detailsVC, animated: true)
    }
    
    // MARK: - Text selection
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewController?.selectedTextView = textView
    }
    
    // MARK: - Search
    
    var currentSearchText: String?
    
    var cellInteractionEnabled: Bool {
        chatViewController?.cellInteractionEnabled ?? false
    }
    
    // MARK: - Retry & cancel
        
    /// Method which tries to resend an unsent message. In case of BlobMessages the method cancels the resending if the
    /// message is already uploading
    /// - Parameter messageObjectID: Managed object ID of the message to be loaded
    func retryOrCancelSendingMessage(withID messageID: NSManagedObjectID, from sourceView: UIView) {
        guard let message = entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessageEntity else {
            DDLogError("Message could not be loaded.")
            return
        }
        
        // If it is not a message of type BlobData, we simply resend
        guard let blobDataMessage = message as? BlobData else {
            resendMessage(withID: messageID, from: sourceView)
            return
        }
      
        switch blobDataMessage.blobDisplayState {
        case .pending, .sendingError:
            resendMessage(withID: messageID, from: sourceView)
        case .uploading:
            Task {
                await BlobManager.shared.cancelBlobsSync(for: message.objectID)
            }
        default:
            assertionFailure("RetryAndCancelButton should not have been visible")
            DDLogError("RetryAndCancelButton button should not have been visible")
        }
    }
    
    private func resendMessage(withID messageID: NSManagedObjectID, from sourceView: UIView) {
        let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)

        let rejectedByGroupMembers = backgroundBusinessInjector.entityManager.performAndWait {
            let message = backgroundBusinessInjector.entityManager.entityFetcher
                .existingObject(with: messageID) as? BaseMessageEntity

            var rejectedBy: Set<ContactEntity>? = nil
            if message?.conversation.isGroup ?? false, !(message?.rejectedBy?.isEmpty ?? true) {
                rejectedBy = message?.rejectedBy
            }
            
            return rejectedBy?.map { Contact(contactEntity: $0) }
        }
        
        // If the message was rejected (FS) by a set of group members ask for confirmation before doing resend
        if let rejectedByGroupMembers, !rejectedByGroupMembers.isEmpty {
            let rejectedMemberNames = rejectedByGroupMembers.map(\.displayName)
            let rejectedMemberIdentities = rejectedByGroupMembers.map(\.identity)
            
            guard let chatViewController else {
                DDLogError("No chat view controller to ask for resend confirmation")
                return
            }
            
            UIAlertTemplate.showConfirm(
                owner: chatViewController,
                popOverSource: sourceView,
                title: #localize("chat_view_resend_group_message_confirmation_title"),
                message: String.localizedStringWithFormat(
                    #localize("chat_view_resend_group_message_confirmation_message"),
                    rejectedMemberNames.formatted()
                ),
                titleOk: #localize("chat_view_resend_group_message_confirmation_button"),
                actionOk: { _ in
                    Task {
                        await backgroundBusinessInjector.messageSender.sendBaseMessage(
                            with: messageID,
                            to: .groupMembers(rejectedMemberIdentities)
                        )
                    }
                },
                titleCancel: #localize("cancel")
            )
        }
        else {
            Task {
                await backgroundBusinessInjector.messageSender.sendBaseMessage(with: messageID)
            }
        }
    }
}
