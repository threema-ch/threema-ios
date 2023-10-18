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

/// Display file messages
final class ChatViewFileMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewFileMessageTableViewCell()
    
    /// File message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var fileMessageAndNeighbors: (message: FileMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            updateCell(for: fileMessageAndNeighbors?.message)
            
            super.setMessage(
                to: fileMessageAndNeighbors?.message,
                with: fileMessageAndNeighbors?.neighbors
            )
        }
    }
    
    override var shouldShowDateAndState: Bool {
        didSet {
            if !(fileMessageAndNeighbors?.message.showDateAndStateInline ?? false) {
                messageDateAndStateView.isHidden = !shouldShowDateAndState
            }
        }
    }
    
    // MARK: - Views & constraints
    
    private lazy var fileTapView = MessageFileTapView { [weak self] in
        self?.chatViewTableViewCellDelegate?.didTap(message: self?.fileMessageAndNeighbors?.message, in: self)
    }
    
    // These are only shown if there is a caption...
    private lazy var captionTextLabel = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    private lazy var captionStack = DefaultMessageContentStackView(arrangedSubviews: [
        captionTextLabel,
        messageDateAndStateView,
    ])
    
    private lazy var fileTapViewCaptionBottomConstraint = fileTapView.bottomAnchor.constraint(
        equalTo: captionStack.topAnchor
    )
    private lazy var fileTapViewNoCaptionBottomConstraint = fileTapView
        .bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
    
    private lazy var rootView: UIView = {
        
        let view = UIView()
        
        // This adds the margin to the chat bubble border
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.File.defaultMargin,
            leading: -ChatViewConfiguration.File.defaultMargin,
            bottom: -ChatViewConfiguration.File.defaultMargin,
            trailing: -ChatViewConfiguration.File.defaultMargin
        )
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        rootView.addSubview(fileTapView)
        rootView.addSubview(captionStack)
        
        fileTapView.translatesAutoresizingMaskIntoConstraints = false
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            fileTapView.topAnchor.constraint(equalTo: rootView.topAnchor),
            fileTapView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            fileTapView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            
            fileTapViewCaptionBottomConstraint,
            
            captionStack.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor, constant: ChatViewConfiguration.File.fileLeadingTrailingInset
            ),
            captionStack.bottomAnchor.constraint(
                equalTo: rootView.bottomAnchor, constant: -ChatViewConfiguration.File.fileTopBottomInset
            ),
            captionStack.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor, constant: -ChatViewConfiguration.File.fileLeadingTrailingInset
            ),
        ])
        
        super.addContent(rootView: rootView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        fileTapView.updateColors()
        captionTextLabel.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        fileTapView.isUserInteractionEnabled = !editing
    }
    
    override func highlightTappableAreasOfCell(_ highlight: Bool) {
        UIView.animate(
            withDuration: ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightFadeInOutDuration,
            delay: .zero,
            options: .curveEaseInOut
        ) {
            self.fileTapView.backgroundColor = highlight ? self.selectedBubbleBackgroundColor : .clear
        }
    }

    private func updateCell(for fileMessage: FileMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        fileTapView.fileMessage = fileMessage
        fileTapView.delegate = self
        
        if !(fileMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = fileMessage?.caption
            messageDateAndStateView.message = fileMessage
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
        
        captionTextLabel.isHidden = false
        messageDateAndStateView.isHidden = false
        captionStack.isHidden = false
        NSLayoutConstraint.deactivate([fileTapViewNoCaptionBottomConstraint])
        NSLayoutConstraint.activate([fileTapViewCaptionBottomConstraint])
    }
    
    private func hideCaptionAndDateAndState() {
        guard !captionStack.isHidden else {
            return
        }
        
        captionTextLabel.isHidden = true
        messageDateAndStateView.isHidden = true
        captionStack.isHidden = true
        NSLayoutConstraint.deactivate([fileTapViewCaptionBottomConstraint])
        NSLayoutConstraint.activate([fileTapViewNoCaptionBottomConstraint])
    }
}

// MARK: - ChatViewMessageAction

extension ChatViewFileMessageTableViewCell: ChatViewMessageAction {
    
    func messageActions() -> [ChatViewMessageActionProvider.MessageAction]? {

        guard let message = fileMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionProvider
        var menuItems = [ChatViewMessageActionProvider.MessageAction]()
        
        // Speak
        var speakText = message.fileMessageType.localizedDescription
        speakText += ", " + message.name
        
        if let caption = message.caption {
            speakText += ", " + caption
        }
        
        // Copy
        let copyHandler = {
            guard let data = message.blobData else {
                NotificationPresenterWrapper.shared.present(type: .copyError)
                return
            }
            UIPasteboard.general.setData(data, forPasteboardType: message.blobUTTypeIdentifier!)
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]
        
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
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        let willDelete = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        // Ack
        let ackHandler = { (message: BaseMessage, ack: Bool) in
            self.chatViewTableViewCellDelegate?.sendAck(for: message, ack: ack)
        }
        
        let defaultActions = Provider.defaultActions(
            message: message,
            speakText: speakText,
            shareItems: shareItems,
            activityViewAnchor: contentView,
            copyHandler: copyHandler,
            quoteHandler: quoteHandler,
            detailsHandler: detailsHandler,
            editHandler: editHandler,
            willDelete: willDelete,
            didDelete: didDelete,
            ackHandler: ackHandler
        )
        
        menuItems.append(contentsOf: defaultActions)
        
        if message.blobDisplayState == .remote {
            let downloadAction = Provider.downloadAction {
                Task {
                    await BlobManager.shared.syncBlobs(for: message.objectID)
                }
            }
            // Download action is inserted before default action, depending if ack/dec is possible at a different
            // position
            if message.isUserAckEnabled {
                menuItems.insert(downloadAction, at: 2)
            }
            else {
                menuItems.insert(downloadAction, at: 0)
            }
        }
        
        // Retry
        if message.showRetryAndCancelButton {
            let retryHandler = Provider.retryAction {
                self.chatViewTableViewCellDelegate?.retryOrCancelSendingMessage(withID: message.objectID)
            }
            
            // Retry action position analogously to download
            if message.isUserAckEnabled {
                menuItems.insert(retryHandler, at: 2)
            }
            else {
                menuItems.insert(retryHandler, at: 0)
            }
        }
        return menuItems
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            buildAccessibilityCustomActions()
        }
        set {
            // No-op
        }
    }
}

// MARK: - Reusable

extension ChatViewFileMessageTableViewCell: Reusable { }

// MARK: - MessageTextViewDelegate

extension ChatViewFileMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - MessageFileTapViewDelegate

extension ChatViewFileMessageTableViewCell: MessageFileTapViewDelegate { }
