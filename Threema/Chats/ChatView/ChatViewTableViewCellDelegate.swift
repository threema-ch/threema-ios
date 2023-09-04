//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
    func swipeMessageTableViewCell(
        swipeMessageTableViewCell: ChatViewBaseTableViewCell,
        recognizer: UIPanGestureRecognizer
    )
    
    func configure(swipeGestureRecognizer: UIPanGestureRecognizer)
    
    func playNextMessageIfPossible(from message: NSManagedObjectID)

    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?)
    func resendMessage(withID messageID: NSManagedObjectID)
    func showQuoteView(message: QuoteMessage)
    func startMultiselect(with messageObjectID: NSManagedObjectID)
    
    func quoteTapped(on quotedMessageID: Data)
    func show(identity: String)
    func open(url: URL)
    func clearCellHeightCache(for objectID: NSManagedObjectID)
    func showDetails(for messageID: NSManagedObjectID)
    func willDeleteMessage(with objectID: NSManagedObjectID)
    func didDeleteMessages()
    func sendAck(for message: BaseMessage, ack: Bool)
    func retryOrCancelSendingMessage(withID messageID: NSManagedObjectID)
    
    func didSelectText(in textView: MessageTextView?)
    
    var currentSearchText: String? { get }
    
    var cellInteractionEnabled: Bool { get }
    
    var chatViewHasCustomBackground: Bool { get }
    
    var chatViewIsGroupConversation: Bool { get }
}

extension ChatViewTableViewCellDelegateProtocol {
    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?) {
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

    var chatViewHasCustomBackground: Bool {
        guard let objectID = chatViewController?.conversation.objectID else {
            return false
        }
        return !(
            WallpaperStore.shared.defaultIsEmptyWallpaper() || WallpaperStore.shared.defaultIsThreemaWallpaper()
        ) ||
            WallpaperStore.shared.hasCustomWallpaper(for: objectID)
    }
    
    // MARK: - Group Conversation flag

    var chatViewIsGroupConversation: Bool {

        guard let conversation = chatViewController?.conversation else {
            return false
        }
        return conversation.isGroup()
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
    
    func open(url: URL) {
        guard let chatViewController else {
            return
        }
        
        IDNSafetyHelper.safeOpen(url: url, viewController: chatViewController)
    }
    
    func didTap(message: BaseMessage?, in cell: ChatViewBaseTableViewCell?, customDefaultAction: (() -> Void)?) {
        
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
    
    func resendMessage(withID messageID: NSManagedObjectID) {
        let businessInjector = BusinessInjector()
        guard let message = businessInjector.entityManager.performAndWait({
            let fetchedMessage = businessInjector.entityManager.entityFetcher
                .existingObject(with: messageID) as? BaseMessage
            fetchedMessage?.id = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)
            return fetchedMessage
        })
        else {
            DDLogError("Message to be re-sent could not be loaded.")
            return
        }
        
        switch message {
        case is FileMessage:
            Task {
                await BlobManager.shared.syncBlobs(for: messageID)
            }
        default:
            businessInjector.messageSender.sendMessage(baseMessage: message)
        }
    }
    
    // MARK: - Multi-Select
    
    func startMultiselect(with messageObjectID: NSManagedObjectID) {
        chatViewController?.startMultiselect(with: messageObjectID)
    }
    
    func sendAck(for message: BaseMessage, ack: Bool) {
        
        guard !UIAccessibility.isVoiceOverRunning else {
            ChatViewTableViewCellDelegate.sendAck(message: message, ack: ack)
            return
        }
        
        let block = {
            ChatViewTableViewCellDelegate.sendAck(message: message, ack: ack)
        }
        chatViewController?.contextMenuActionsQueue.append(block)
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
    
    // MARK: - Helpers
    
    ///  Processes sending thumbsUp or thumbsDown
    private static func sendAck(message: BaseMessage, ack: Bool) {
        let businessInjector = BusinessInjector()
        
        guard let baseMessage = businessInjector.entityManager.entityFetcher
            .existingObject(with: message.objectID) as? BaseMessage,
            let conversation = baseMessage.conversation else {
            return
        }
        
        let group = businessInjector.groupManager.getGroup(conversation: conversation)
        var contact: ContactEntity?
        
        if conversation.isGroup() {
            if baseMessage.isMyReaction(ack ? .acknowledged : .declined) {
                return
            }
        }
        else {
            guard let c = conversation.contact else {
                return
            }
            contact = c
            // Only send changed acks
            if baseMessage.userackDate != nil, let currentAck = baseMessage.userack, currentAck.boolValue == ack {
                return
            }
        }
        let identity = contact?.identity

        Task { @MainActor in
            if ack {
                if let group {
                    await businessInjector.messageSender.sendUserAck(for: baseMessage, toGroup: group)
                }
                else if let identity {
                    await businessInjector.messageSender.sendUserAck(for: baseMessage, toIdentity: identity)
                }
            }
            else {
                if let group {
                    await businessInjector.messageSender.sendUserDecline(for: baseMessage, toGroup: group)
                }
                else if let identity {
                    await businessInjector.messageSender.sendUserDecline(for: baseMessage, toIdentity: identity)
                }
            }
        }
    }
    
    // MARK: - Retry
    
    /// Method which tries to resend an unsent message. In case of BlobMessages the method cancels the resending if the
    /// message is already uploading
    /// - Parameter messageObjectID: Managed object ID of the message to be loaded
    func retryOrCancelSendingMessage(withID messageID: NSManagedObjectID) {
        guard let message = entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessage else {
            DDLogError("Message could not be loaded.")
            return
        }
        
        // If it is not a message of type BlobData, we simply resend
        guard let fileMessage = message as? BlobData else {
            resendMessage(withID: messageID)
            return
        }
      
        switch fileMessage.blobDisplayState {

        case .pending:
            Task {
                await BlobManager.shared.syncBlobs(for: message.objectID)
            }
        case .sendingError:
            // If a message could not be sent we might only have missed the ack from the chat server
            // If this is the case a message with the same message ID as the previously sent one will be rejected
            // This also applied to messages that have been rejected by the receiver due to missing or incorrect session
            // state
            let businessInjector = BusinessInjector()
            guard let message = businessInjector.entityManager.performAndWait({
                let fetchedMessage = businessInjector.entityManager.entityFetcher
                    .existingObject(with: message.objectID) as? BaseMessage
                fetchedMessage?.id = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)
                return fetchedMessage
            })
            else {
                DDLogError("Message to be re-sent could not be loaded.")
                return
            }
            
            Task {
                await BlobManager.shared.syncBlobs(for: message.objectID)
            }
        case .uploading:
            Task {
                await BlobManager.shared.cancelBlobsSync(for: message.objectID)
            }
        default:
            assertionFailure("RetryAndCancelButton should not have been visible")
            DDLogError("RetryAndCancelButton button should not have been visible")
        }
    }
}
