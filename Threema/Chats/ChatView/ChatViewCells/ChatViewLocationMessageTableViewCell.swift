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

/// Display a location message
final class ChatViewLocationMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    static var sizingCell = ChatViewLocationMessageTableViewCell()
    
    /// Location message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var locationMessageAndNeighbors: (message: LocationMessageEntity, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            let block = {
                self.updateCell(for: self.locationMessageAndNeighbors?.message)
            
                super.setMessage(
                    to: self.locationMessageAndNeighbors?.message,
                    with: self.locationMessageAndNeighbors?.neighbors
                )
            }
            
            if let oldValue, oldValue.message.objectID == locationMessageAndNeighbors?.message.objectID {
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
    
    override var shouldShowDateAndState: Bool {
        didSet {
            // Both of these animations are typically covered within a bigger animation block
            // or a block that doesn't animate at all. Both cases look good.
            if shouldShowDateAndState {
                    
                let block = {
                    self.messageDateAndStateView.alpha = 1.0
                    self.messageDateAndStateView.isHidden = false
                }
                    
                if !oldValue {
                    // When adding the date and state view, this is an animation that doesn't look half bad since the
                    // view will animate in from the bottom.
                    UIView.animate(
                        withDuration: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        delay: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        options: .curveEaseInOut
                    ) {
                        block()
                    }
                }
                else {
                    UIView.performWithoutAnimation {
                        block()
                    }
                }
            }
            else {
                // We don't use the same animation when hiding the date and state view because it'll animate out to the
                // top and will cover the text which is still showing in the cell.
                UIView.performWithoutAnimation {
                    self.messageDateAndStateView.alpha = 0.0
                }
            }
                
            messageDateAndStateView.isHidden = !shouldShowDateAndState
        }
    }
    
    // MARK: - Views
    
    private lazy var iconView: UIImageView = {
        
        let configuration = ChatViewConfiguration.Text.symbolConfiguration
        let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: configuration)?
            .withTintColor(.label, renderingMode: .alwaysOriginal)
        
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        iconMessageContentView.isUserInteractionEnabled = !editing
    }
    
    private func updateCell(for locationMessage: LocationMessageEntity?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        // Clear cache for cell, if address was newly added
        if let locationMessage,
           messageTextView.text != nil,
           messageSecondaryTextLabel.text == nil {
            chatViewTableViewCellDelegate?.clearCellHeightCache(for: locationMessage.objectID)
        }
        
        if let poiName = locationMessage?.poiName, poiName.isEmpty == false {
            messageTextView.text = poiName
            messageTextView.isHidden = false
        }
        else {
            messageTextView.text = ""
            messageTextView.isHidden = true
        }
                
        if let poiAddress = locationMessage?.poiAddress, poiAddress.isEmpty == false {
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

// MARK: - ChatViewMessageActions

extension ChatViewLocationMessageTableViewCell: ChatViewMessageActions {
    
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]? {
        
        guard let message = locationMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionsProvider

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
        
        // MessageMarkers
        let markStarHandler = { (message: BaseMessageEntity) in
            self.chatViewTableViewCellDelegate?.toggleMessageMarkerStar(message: message)
        }
        
        // Quote
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                return
            }
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        // Copy
        let copyHandler = {
            UIPasteboard.general.string = locationSummary
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        // Share
        let shareItems = [locationSummary as Any]
        
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
            quoteHandler: quoteHandler,
            copyHandler: copyHandler,
            shareItems: shareItems,
            speakText: locationSummary,
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
