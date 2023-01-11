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

/// Display animated sticker messages
final class ChatViewAnimatedStickerMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewAnimatedStickerMessageTableViewCell()

    /// ThumbnailDisplay message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var animatedStickerMessageAndNeighbors: (
        message: StickerMessage,
        neighbors: ChatViewDataSource.MessageNeighbors
    )? {
        didSet {
            updateCell(for: animatedStickerMessageAndNeighbors?.message)
            
            super.setMessage(
                to: animatedStickerMessageAndNeighbors?.message,
                with: animatedStickerMessageAndNeighbors?.neighbors
            )
        }
    }
    
    override var bubbleBackgroundColor: UIColor {
        .clear
    }
    
    override var selectedBubbleBackgroundColor: UIColor {
        .clear
    }
    
    // MARK: - Views & constraints
    
    private lazy var animatedImageTapView = MessageAnimatedMediaTapView { [weak self] in
        guard let strongSelf = self else {
            return
        }
        
        strongSelf.chatViewTableViewCellDelegate?.didTap(
            message: strongSelf.animatedStickerMessageAndNeighbors?.message,
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
        
        captionTextLabel.updateColors()
        animatedImageTapView.updateColors()
        messageDateAndStateView.updateColors()
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

extension ChatViewAnimatedStickerMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - ContextMenuAction

extension ChatViewAnimatedStickerMessageTableViewCell: ContextMenuAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
       
        guard let message = animatedStickerMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewContextMenuActionProvider
        var menuItems = [UIAction]()
        
        // Speak
        var speakText = message.fileMessageType.localizedDescription
        if let caption = message.caption {
            speakText += ", " + caption
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]

        // Copy
        // In the new chat view we always copy the data, regardless if it has a caption because the text can be selected itself.
        let copyHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                fatalError()
            }
            
            guard let data = message.blobGet(),
                  let uti = message.blobGetUTI() else {
                NotificationPresenterWrapper.shared.present(type: .copyError)
                return
            }
            UIPasteboard.general.setData(data, forPasteboardType: uti)
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
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
        
        // Details
        let detailsHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Edit
        let editHandler = {
            self.chatViewTableViewCellDelegate?.startMultiselect()
        }
        
        // Save
        let albumManager = AlbumManager.shared
        let saveHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                fatalError()
            }
            
            guard let data = message.blobGet() else {
                NotificationPresenterWrapper.shared.present(type: .saveError)
                return
            }
            albumManager.saveAnimatedImage(data: data)
        }
        
        let defaultActions = Provider.defaultActions(
            message: message,
            speakText: speakText,
            shareItems: shareItems,
            activityViewAnchor: contentView,
            copyHandler: copyHandler,
            quoteHandler: quoteHandler,
            detailsHandler: detailsHandler,
            editHandler: editHandler
        )
        
        let saveAction = Provider.saveAction(handler: saveHandler)
        
        // Build menu
        menuItems.append(contentsOf: defaultActions)
        
        // Save action is inserted before default action, depending if ack/dec is possible at a different position
        if !MDMSetup(setup: false).disableShareMedia() {
            if message.isUserAckEnabled {
                menuItems.insert(saveAction, at: 2)
            }
            else {
                menuItems.insert(saveAction, at: 0)
            }
        }
        
        let menu = UIMenu(children: menuItems)
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}

// MARK: - Reusable

extension ChatViewAnimatedStickerMessageTableViewCell: Reusable { }
