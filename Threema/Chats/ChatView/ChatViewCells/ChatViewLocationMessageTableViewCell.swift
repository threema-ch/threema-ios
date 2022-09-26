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
import ThreemaFramework
import UIKit

/// Display a location message
final class ChatViewLocationMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell, MessageTextViewDelegate {
    static var sizingCell = ChatViewLocationMessageTableViewCell()
    
    /// Location message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var locationMessage: LocationMessage? {
        didSet {
            super.setMessage(to: locationMessage)
            updateCell(for: locationMessage)
        }
    }
    
    // MARK: - Views
    
    private lazy var iconView: UIImageView = {
        
        let configuration = ChatViewConfiguration.Text.symbolConfiguration
        let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: configuration)?
            .withTintColor(Colors.text, renderingMode: .alwaysOriginal)
        
        let imageView = UIImageView(image: image)
        imageView.accessibilityElementsHidden = true
        return imageView
    }()
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageSecondaryTextLabel = MessageSecondaryTextLabel()
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var iconMessageContentView = IconMessageContentView(
        iconView: iconView,
        arrangedSubviews: [
            messageTextView,
            messageSecondaryTextLabel,
            messageDateAndStateView,
        ]
    )
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        super.addContent(rootView: iconMessageContentView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        iconView.image = iconView.image?.withTintColor(Colors.text)
        messageTextView.updateColors()
        messageSecondaryTextLabel.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for locationMessage: LocationMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        // Clear cache for cell, if address was newly added
        if let locationMessage = locationMessage,
           messageTextView.text != nil,
           messageSecondaryTextLabel.text == nil {
            chatViewTableViewCellDelegate?.clearCellHeightCache(for: locationMessage.objectID)
        }
        
        // TODO: (IOS-2390) Replace by correct name label implementation
        if let locationMessage = locationMessage,
           locationMessage.conversation.isGroup(),
           !locationMessage.isOwnMessage {
            messageTextView.text = "\(locationMessage.quotedSender): \(locationMessage.poiName ?? "")"
            messageTextView.isHidden = false
        }
        else {
            messageTextView.text = locationMessage?.poiName
            messageTextView.isHidden = messageTextView.text.isEmpty
        }
        messageSecondaryTextLabel.text = locationMessage?.poiAddress
    
        messageDateAndStateView.message = locationMessage
    }
}

// MARK: - Reusable

extension ChatViewLocationMessageTableViewCell: Reusable { }

// MARK: - ContextMenuAction

extension ChatViewLocationMessageTableViewCell: ContextMenuAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        
        guard let message = locationMessage else {
            return nil
        }

        typealias Provider = ChatViewContextMenuActionProvider
        var menuItems = [UIAction]()

        // We create a more readable string
        var locationSummary = ""
        if let poiName = message.poiName {
            locationSummary += poiName
        }
        if let poiAddress = message.poiAddress {
            locationSummary += "\n" + poiAddress
        }
        
        if locationSummary.isEmpty {
            DDLogError(
                "Location-summary of location message cell was empty, which means poiName and poiAddress were both nil."
            )
        }
        
        let copyHandler = {
            UIPasteboard.general.string = locationSummary
        }
        let shareItems = [locationSummary as Any]
        
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                return
            }
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        let defaultActions = Provider.defaultActions(
            message: message,
            speakText: locationSummary,
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
