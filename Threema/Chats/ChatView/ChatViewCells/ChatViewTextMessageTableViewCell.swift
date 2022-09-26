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

/// Display a text message
final class ChatViewTextMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewTextMessageTableViewCell()
    
    /// Text message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var textMessage: TextMessage? {
        didSet {
            super.setMessage(to: textMessage)
            updateCell(for: textMessage)
        }
    }
    
    // MARK: - Views
    
    private lazy var messageQuoteStackView = MessageQuoteStackView()
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        messageQuoteStackView,
        messageTextView,
        messageDateAndStateView,
    ])

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        super.addContent(rootView: contentStack)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        messageQuoteStackView.updateColors()
        messageTextView.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for textMessage: TextMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        messageQuoteStackView.quoteMessage = textMessage?.quoteMessage
        
        // TODO: (IOS-2390) Replace by correct name label implementation
        if let textMessage = textMessage,
           textMessage.conversation.isGroup(),
           !textMessage.isOwnMessage {
            messageTextView.text = "\(textMessage.quotedSender): \(textMessage.text ?? "")"
        }
        else {
            messageTextView.text = textMessage?.text ?? ""
        }
        
        messageDateAndStateView.message = textMessage
        
        // We hide the quote stack view if there is no quoted message
        if textMessage?.quoteMessage == nil {
            messageQuoteStackView.isHidden = true
        }
        else {
            messageQuoteStackView.isHidden = false
        }
        
        updateAccessibility()
    }
    
    private func updateAccessibility() {
        guard let textMessage = textMessage else {
            return
        }
        
        // TODO: construct accessibility label for different types
        if textMessage.quoteMessage != nil {
            accessibilityHint = BundleUtil.localizedString(forKey: "quote_interaction_hint")
        }
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewTextMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
}

// MARK: - Reusable

extension ChatViewTextMessageTableViewCell: Reusable { }

// MARK: - ContextMenuAction

extension ChatViewTextMessageTableViewCell: ContextMenuAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
       
        guard let message = textMessage else {
            return nil
        }

        typealias Provider = ChatViewContextMenuActionProvider
        var menuItems = [UIAction]()
        
        let copyHandler = {
            UIPasteboard.general.string = message.text
        }
        let shareItems = [message.text as Any]
        
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                return
            }
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        let defaultActions = Provider.defaultActions(
            message: message,
            speakText: message.text,
            shareItems: shareItems,
            copyHandler: copyHandler,
            quoteHandler: quoteHandler
        )
        
        menuItems.append(contentsOf: defaultActions)
        
        // Build menu
        let menu = UIMenu(children: menuItems)
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}
