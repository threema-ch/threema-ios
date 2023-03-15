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
import ThreemaFramework
import UIKit

/// Display a location message
final class ChatViewLocationMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    static var sizingCell = ChatViewLocationMessageTableViewCell()
    
    /// Location message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var locationMessageAndNeighbors: (message: LocationMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            updateCell(for: locationMessageAndNeighbors?.message)
            
            super.setMessage(to: locationMessageAndNeighbors?.message, with: locationMessageAndNeighbors?.neighbors)
        }
    }
    
    override var shouldShowDateAndState: Bool {
        didSet {
            messageDateAndStateView.isHidden = !shouldShowDateAndState
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
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: nil)
    private lazy var messageSecondaryTextLabel = MessageSecondaryTextLabel()
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var iconMessageContentView = IconMessageContentView(
        iconView: iconView,
        arrangedSubviews: [
            messageTextView,
            messageSecondaryTextLabel,
            messageDateAndStateView,
        ]
    ) { [weak self] in
        guard let strongSelf = self else {
            return
        }
        
        strongSelf.chatViewTableViewCellDelegate?.didTap(
            message: strongSelf.locationMessageAndNeighbors?.message,
            in: strongSelf
        )
    }
    
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        iconMessageContentView.isUserInteractionEnabled = !editing
    }
    
    private func updateCell(for locationMessage: LocationMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        // Clear cache for cell, if address was newly added
        if let locationMessage = locationMessage,
           messageTextView.text != nil,
           messageSecondaryTextLabel.text == nil {
            chatViewTableViewCellDelegate?.clearCellHeightCache(for: locationMessage.objectID)
        }
        
        if let poiName = locationMessage?.poiName {
            messageTextView.text = poiName
        }
        
        messageTextView.isHidden = messageTextView.text.isEmpty
        if let poiAddress = locationMessage?.poiAddress {
            messageSecondaryTextLabel.text = poiAddress
        }
        else {
            messageSecondaryTextLabel.text = locationMessage?.formattedCoordinates
        }
        messageDateAndStateView.message = locationMessage
    }
}

// MARK: - Reusable

extension ChatViewLocationMessageTableViewCell: Reusable { }

// MARK: - ChatViewMessageAction

extension ChatViewLocationMessageTableViewCell: ChatViewMessageAction {
    
    func messageActions() -> [ChatViewMessageActionProvider.MessageAction]? {

        guard let message = locationMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionProvider
        var menuItems = [ChatViewMessageActionProvider.MessageAction]()

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
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        let shareItems = [locationSummary as Any]
        
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
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
            speakText: locationSummary,
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
