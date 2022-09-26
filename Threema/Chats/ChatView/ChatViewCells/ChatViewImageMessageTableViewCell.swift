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

import ThreemaFramework
import UIKit

/// Display image messages
final class ChatViewImageMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewImageMessageTableViewCell()

    /// Image message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var imageMessage: ImageMessage? {
        didSet {
            super.setMessage(to: imageMessage)
            updateCell(for: imageMessage)
        }
    }
    
    // MARK: - Views & constraints
    
    private lazy var thumbnailButton = MessageThumbnailButton { _ in
        // TODO: (IOS-2590) Implement
        self.chatViewTableViewCellDelegate?.didTap(message: self.imageMessage)
        
        print("Thumbnail pressed")
    }
    
    private lazy var thumbnailButtonCaptionBottomConstraint = thumbnailButton.bottomAnchor.constraint(
        equalTo: captionStack.topAnchor
    )
    private lazy var thumbnailButtonNoCaptionBottomConstraint = thumbnailButton.layoutMarginsGuide
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
        
        rootView.addSubview(thumbnailButton)
        rootView.addSubview(captionStack)
        
        thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thumbnailButton.layoutMarginsGuide.topAnchor.constraint(equalTo: rootView.topAnchor),
            thumbnailButton.layoutMarginsGuide.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            thumbnailButton.layoutMarginsGuide.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            
            thumbnailButtonCaptionBottomConstraint,
            
            captionStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            captionStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            captionStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        ])
        
        super.addContent(rootView: rootView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        captionTextLabel.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for imageMessage: ImageMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        thumbnailButton.thumbnailDisplayMessage = imageMessage
        
        if !(imageMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = imageMessage?.caption
            messageDateAndStateView.message = imageMessage
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
        NSLayoutConstraint.deactivate([thumbnailButtonNoCaptionBottomConstraint])
        NSLayoutConstraint.activate([thumbnailButtonCaptionBottomConstraint])
    }
    
    private func hideCaptionAndDateAndState() {
        guard !captionStack.isHidden else {
            return
        }
        
        captionStack.isHidden = true
        NSLayoutConstraint.deactivate([thumbnailButtonCaptionBottomConstraint])
        NSLayoutConstraint.activate([thumbnailButtonNoCaptionBottomConstraint])
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewImageMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
}

// MARK: - Reusable

extension ChatViewImageMessageTableViewCell: Reusable { }
