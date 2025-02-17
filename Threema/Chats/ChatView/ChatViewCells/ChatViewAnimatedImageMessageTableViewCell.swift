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
import ThreemaFramework
import UIKit

/// Display animated image messages
final class ChatViewAnimatedImageMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewAnimatedImageMessageTableViewCell()

    /// ThumbnailDisplay message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var animatedImageMessageAndNeighbors: (
        message: ImageMessage,
        neighbors: ChatViewDataSource.MessageNeighbors
    )? {
        didSet {
            let block = {
                self.updateCell(for: self.animatedImageMessageAndNeighbors?.message)
                
                super.setMessage(
                    to: self.animatedImageMessageAndNeighbors?.message,
                    with: self.animatedImageMessageAndNeighbors?.neighbors
                )
            }
            
            if let oldValue, oldValue.message.objectID == animatedImageMessageAndNeighbors?.message.objectID {
                UIView.animate(
                    withDuration: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                    delay: 0.0,
                    options: .curveEaseInOut
                ) {
                    block()
                    self.layoutIfNeeded()
                }
            }
            else {
                block()
            }
        }
    }
    
    // MARK: - Views & constraints
    
    private lazy var animatedImageTapView = MessageAnimatedMediaTapView { [weak self] in
        guard let strongSelf = self else {
            return
        }
        
        strongSelf.chatViewTableViewCellDelegate?.didTap(
            message: strongSelf.animatedImageMessageAndNeighbors?.message,
            in: strongSelf,
            customDefaultAction: {
                strongSelf.toggleMediaAnimation()
            }
        )
    }
    
    private lazy var animatedImageTapViewCaptionBottomConstraint = animatedImageTapView.bottomAnchor.constraint(
        equalTo: captionStack.topAnchor, constant: -ChatViewConfiguration.Content.defaultTopBottomInset
    )
    private lazy var animatedImageTapViewNoCaptionBottomConstraint = animatedImageTapView
        .bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
    
    // These are only shown if there is a caption...
    private lazy var captionTextLabel = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    private lazy var captionStack = DefaultMessageContentStackView(arrangedSubviews: [
        captionTextLabel,
        messageDateAndStateView,
    ])
    
    private lazy var rootView = UIView()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        // This adds the margin to the chat bubble border
        rootView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Thumbnail.defaultMargin,
            leading: -ChatViewConfiguration.Thumbnail.defaultMargin,
            bottom: -ChatViewConfiguration.Thumbnail.defaultMargin,
            trailing: -ChatViewConfiguration.Thumbnail.defaultMargin
        )
        
        rootView.addSubview(animatedImageTapView)
        rootView.addSubview(captionStack)
        
        animatedImageTapView.translatesAutoresizingMaskIntoConstraints = false
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            animatedImageTapView.topAnchor.constraint(equalTo: rootView.topAnchor),
            animatedImageTapView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            animatedImageTapView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            
            animatedImageTapViewCaptionBottomConstraint,
            
            captionStack.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor,
                constant: ChatViewConfiguration.Content.defaultLeadingTrailingInset
            ),
            captionStack.bottomAnchor.constraint(
                equalTo: rootView.bottomAnchor,
                constant: -ChatViewConfiguration.Content.defaultTopBottomInset
            ),
            captionStack.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor,
                constant: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
            ),
        ])
        
        super.addContent(rootView: rootView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        animatedImageTapView.updateColors()
    }
    
    private func updateCell(for thumbnailDisplayMessage: ThumbnailDisplayMessage?) {
        // By accepting an optional the data is automatically reset when the message is set to `nil`
        
        animatedImageTapView.thumbnailDisplayMessage = thumbnailDisplayMessage
        
        if !(thumbnailDisplayMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = thumbnailDisplayMessage?.caption
            messageDateAndStateView.message = thumbnailDisplayMessage
            showCaptionAndDateAndState()
        }
        else {
            hideCaptionAndDateAndState()
        }
    }
    
    override func highlightTappableAreasOfCell(_ highlight: Bool) {
        animatedImageTapView.highlight(highlight)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
       
        animatedImageTapView.isUserInteractionEnabled = !editing

        if editing {
            animatedImageTapView.stopMediaAnimation()
        }
    }
    
    private func toggleMediaAnimation() {
        animatedImageTapView.toggleMediaAnimation()
    }
    
    // MARK: - Show and hide
    
    private func showCaptionAndDateAndState() {
        guard captionStack.isHidden else {
            return
        }
        
        captionStack.isHidden = false
        NSLayoutConstraint.deactivate([animatedImageTapViewNoCaptionBottomConstraint])
        NSLayoutConstraint.activate([animatedImageTapViewCaptionBottomConstraint])
    }
    
    private func hideCaptionAndDateAndState() {
        guard !captionStack.isHidden else {
            return
        }
        
        captionStack.isHidden = true
        NSLayoutConstraint.deactivate([animatedImageTapViewCaptionBottomConstraint])
        NSLayoutConstraint.activate([animatedImageTapViewNoCaptionBottomConstraint])
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewAnimatedImageMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - ChatViewMessageActions

extension ChatViewAnimatedImageMessageTableViewCell: ChatViewMessageActions {
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]? {
        
        guard let message = animatedImageMessageAndNeighbors?.message as? ImageMessage else {
            return nil
        }

        typealias Provider = ChatViewMessageActionsProvider
        
        // MessageMarkers
        let markStarHandler = { (message: BaseMessage) in
            self.chatViewTableViewCellDelegate?.toggleMessageMarkerStar(message: message)
        }
        
        // Retry and cancel
        let retryAndCancelHandler = { [weak self] in
            guard let self else {
                return
            }
            
            chatViewTableViewCellDelegate?.retryOrCancelSendingMessage(withID: message.objectID, from: rootView)
        }
        
        // Download
        let downloadHandler: Provider.DefaultHandler = {
            Task {
                await BlobManager.shared.syncBlobs(for: message.objectID)
            }
        }
        
        // Quote
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                DDLogError("[CV CxtMenu] Could not show quote view because the delegate was nil.")
                return
            }
            
            guard let message = message as? QuoteMessage else {
                DDLogError("[CV CxtMenu] Could not show quote view because the message is not a quote message.")
                return
            }
            
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        // Edit
        let editHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.editMessage(for: message.objectID)
        }
        
        // Save
        let saveHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                DDLogWarn(
                    "[ChatViewAnimatedImageMessageTableViewCell] Tried to save media, even if MDM disabled it."
                )
                return
            }
            
            if let saveMediaItem = message.createSaveMediaItem() {
                AlbumManager.shared.save(saveMediaItem)
            }
        }
        
        // Copy
        // In the new chat view we always copy the data, regardless if it has a caption because the text can be selected
        // itself.
        let copyHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                DDLogWarn(
                    "[ChatViewAnimatedImageMessageTableViewCell] Tried to copy media, even if MDM disabled it."
                )
                return
            }
            guard let data = message.blobData,
                  let uti = message.blobUTTypeIdentifier else {
                NotificationPresenterWrapper.shared.present(type: .copyError)
                return
            }
            UIPasteboard.general.setData(data, forPasteboardType: uti)
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]
                
        // Speak
        var speakText = message.fileMessageType.localizedDescription
        if let caption = message.caption, !caption.isEmpty {
            speakText += ", " + caption
        }
        
        // Details
        let detailsHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Select
        let selectHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        
        let willDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        // Build menu
        return Provider.defaultActions(
            message: message,
            activityViewAnchor: contentView,
            popOverSource: chatBubbleContentView,
            markStarHandler: markStarHandler,
            retryAndCancelHandler: retryAndCancelHandler,
            downloadHandler: downloadHandler,
            quoteHandler: quoteHandler,
            editHandler: editHandler,
            saveHandler: saveHandler,
            copyHandler: copyHandler,
            shareItems: shareItems,
            speakText: speakText,
            detailsHandler: detailsHandler,
            selectHandler: selectHandler,
            willDelete: willDelete,
            didDelete: didDelete
        )
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            buildAccessibilityCustomActions(reactionsManager: reactionsManager)
        }
        set {
            // No-op
        }
    }
}

// MARK: - Reusable

extension ChatViewAnimatedImageMessageTableViewCell: Reusable { }
