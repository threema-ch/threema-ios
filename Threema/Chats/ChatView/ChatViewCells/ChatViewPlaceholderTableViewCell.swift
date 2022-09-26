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

import UIKit

// TODO: This is a placeholder cell that should be removed when all cells are implemented
final class ChatViewPlaceholderTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewPlaceholderTableViewCell()
    
    var message: BaseMessage? {
        didSet {
            super.setMessage(to: message)
            updateCell(for: message)
        }
    }
    
    // MARK: - Views

    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        messageTextView,
        messageDateAndStateView,
    ])

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        addContent(rootView: contentStack)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        messageTextView.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for message: BaseMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        // TODO: (IOS-2390) Replace by correct name label implementation
        if let message = message,
           message.conversation.isGroup(),
           !message.isOwnMessage {
            messageTextView.text = "\(message.quotedSender): \(message.logText() ?? "")"
        }
        else {
            messageTextView.text = message?.logText() ?? ""
        }
        
        messageDateAndStateView.message = message
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewPlaceholderTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
}

// MARK: - Reusable

extension ChatViewPlaceholderTableViewCell: Reusable { }
