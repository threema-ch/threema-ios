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
import ThreemaFramework
import UIKit

/// Display image messages
final class ChatViewThumbnailDisplayMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewThumbnailDisplayMessageTableViewCell()

    /// ThumbnailDisplay message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var thumbnailDisplayMessageAndNeighbors: (
        message: ThumbnailDisplayMessage,
        neighbors: ChatViewDataSource.MessageNeighbors
    )? {
        didSet {
            let block = {
                self.updateCell(for: self.thumbnailDisplayMessageAndNeighbors?.message)
                
                super.setMessage(
                    to: self.thumbnailDisplayMessageAndNeighbors?.message,
                    with: self.thumbnailDisplayMessageAndNeighbors?.neighbors
                )
            }
            
            if let oldValue, oldValue.message.objectID == thumbnailDisplayMessageAndNeighbors?.message.objectID {
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
    
    private lazy var thumbnailTapView = MessageThumbnailTapView { [weak self] in
        self?.chatViewTableViewCellDelegate?.didTap(
            message: self?.thumbnailDisplayMessageAndNeighbors?.message,
            in: self
        )
    }
    
    private lazy var thumbnailTapViewCaptionBottomConstraint = thumbnailTapView.bottomAnchor.constraint(
        equalTo: captionStack.topAnchor, constant: -ChatViewConfiguration.Content.defaultTopBottomInset
    )
    private lazy var thumbnailTapViewNoCaptionBottomConstraint = thumbnailTapView
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
        
        rootView.addSubview(thumbnailTapView)
        rootView.addSubview(captionStack)
        
        thumbnailTapView.translatesAutoresizingMaskIntoConstraints = false
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbnailTapView.topAnchor.constraint(equalTo: rootView.topAnchor),
            thumbnailTapView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            thumbnailTapView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            
            thumbnailTapViewCaptionBottomConstraint,
            
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
        
        thumbnailTapView.updateColors()
    }
    
    override func highlightTappableAreasOfCell(_ highlighted: Bool) {
        thumbnailTapView.highlight(highlighted)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        thumbnailTapView.isUserInteractionEnabled = !editing
    }
    
    private func updateCell(for thumbnailDisplayMessage: ThumbnailDisplayMessage?) {
        // By accepting an optional the data is automatically reset when the message is set to `nil`
        
        thumbnailTapView.thumbnailDisplayMessage = thumbnailDisplayMessage
        
        if !(thumbnailDisplayMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = thumbnailDisplayMessage?.caption
            messageDateAndStateView.message = thumbnailDisplayMessage
            showCaptionAndDateAndState()
        }
        else {
            hideCaptionAndDateAndState()
        }
    }
    
    // MARK: - Show and hide
    
    private func showCaptionAndDateAndState() {
        guard captionStack.isHidden else {
            return
        }
        
        captionStack.isHidden = false
        NSLayoutConstraint.deactivate([thumbnailTapViewNoCaptionBottomConstraint])
        NSLayoutConstraint.activate([thumbnailTapViewCaptionBottomConstraint])
    }
    
    private func hideCaptionAndDateAndState() {
        guard !captionStack.isHidden else {
            return
        }
        
        captionStack.isHidden = true
        NSLayoutConstraint.deactivate([thumbnailTapViewCaptionBottomConstraint])
        NSLayoutConstraint.activate([thumbnailTapViewNoCaptionBottomConstraint])
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewThumbnailDisplayMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - ChatViewMessageActions

extension ChatViewThumbnailDisplayMessageTableViewCell: ChatViewMessageActions {
    
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]? {
        
        guard let message = thumbnailDisplayMessageAndNeighbors?.message as? ThumbnailDisplayMessage else {
            return nil
        }

        typealias Provider = ChatViewMessageActionsProvider
            
        // MessageMarkers
        let markStarHandler = { (message: BaseMessageEntity) in
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
        
        // Edit Message
        let editHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.editMessage(for: message.objectID)
        }
        
        // Save
        let saveHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                DDLogWarn(
                    "[ChatViewThumbnailDisplayMessageTableViewCell] Tried to save media, even if MDM disabled it."
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
                    "[ChatViewThumbnailDisplayMessageTableViewCell] Tried to copy media, even if MDM disabled it."
                )
                return
            }
            
            guard let data = message.blobData else {
                NotificationPresenterWrapper.shared.present(type: .copyError)
                return
            }
            
            switch message.fileMessageType {
            case .image, .animatedImage:
                UIPasteboard.general.image = UIImage(data: data)
                NotificationPresenterWrapper.shared.present(type: .copySuccess)
                
            case .video:
                guard let uti = message.blobUTTypeIdentifier else {
                    NotificationPresenterWrapper.shared.present(type: .copyError)
                    break
                }
                UIPasteboard.general.setData(data, forPasteboardType: uti)
                NotificationPresenterWrapper.shared.present(type: .copySuccess)
                
            default:
                DDLogError("[CV CxtMenu] Message has invalid type.")
            }
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]

        // Speak
        var speakText = message.fileMessageType.localizedDescription
        if let caption = message.caption, !caption.isEmpty {
            speakText += ", \(caption)"
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

extension ChatViewThumbnailDisplayMessageTableViewCell: Reusable { }
