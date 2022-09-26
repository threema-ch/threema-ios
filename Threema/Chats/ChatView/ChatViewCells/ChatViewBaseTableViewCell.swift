//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import Foundation
import UIKit

/// Base class for all chat view cells with a chat bubble background
///
/// You should subclass this. If you use this directly it will only show a chat bubble.
///
/// When subclassing call `addContent(rootView:)` once to add the root view of your content views to the cell and set `setMessage(to:)` whenever your message
/// changes.
class ChatViewBaseTableViewCell: ThemedCodeTableViewCell {
    
    /// Delegate used to handle cell delegates
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegate?
    
    /// Background of chat bubble
    ///
    /// Override this method if you want a non-default color background or no bubble at all.
    var bubbleBackgroundColor: UIColor {
        if let message = message, message.isOwnMessage {
            return Colors.chatBubbleSent
        }
        else {
            return Colors.chatBubbleReceived
        }
    }
    
    // MARK: - Internal state
        
    // Used to set correct bubble layout and for `ChatScrollPositionDataProvider` implementation
    fileprivate var message: BaseMessage? {
        didSet {
            guard let message = message else {
                return
            }
            
            if message.isOwnMessage {
                setLayoutForOwnMessage()
            }
            else {
                setLayoutForOtherMessage()
            }
        }
    }
    
    // MARK: Views & constraints
    
    /// Contains the message cell itself, plus the chatBubbleBackgroundView and is added to content view
    lazy var chatBubbleView = UIView()
    
    var chatBubbleBorderPath: UIBezierPath {
        chatBubbleBackgroundView.backgroundPath
    }
    
    private lazy var chatBubbleBackgroundView = ChatBubbleBackgroundView()
    
    private lazy var ownMessageConstraints: [NSLayoutConstraint] = [
        chatBubbleBackgroundView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
    ]
    
    private lazy var otherMessageConstraints: [NSLayoutConstraint] = [
        chatBubbleBackgroundView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
    ]
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        // Configure cell layout
        // TODO: (IOS-2014) Maybe use backgroundView from cell?
        chatBubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chatBubbleView)
        
        chatBubbleBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        chatBubbleView.addSubview(chatBubbleBackgroundView)
        
        // TODO: (IOS-2488 & IOS-2489) Set correct layout guides for content view and test on iPad
        NSLayoutConstraint.activate([
            
            // Leading or trailing constraint for `chatBubbleView` is set by setLayoutFor... below
            chatBubbleView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            chatBubbleView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            
            chatBubbleView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor,
                multiplier: ChatViewConfiguration.ChatBubble.maxWidthRatio
            ),
            
            // Add background to `chatBubbleView`
            chatBubbleBackgroundView.topAnchor.constraint(equalTo: chatBubbleView.topAnchor),
            chatBubbleBackgroundView.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor),
            chatBubbleBackgroundView.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor),
            chatBubbleBackgroundView.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor),
        ])
        
        setLayoutForOtherMessage()
    }
    
    // MARK: - For child classes
    
    /// Add root view that contains all content shown in this cell
    ///
    /// You should call this only *once* with a view that will contain all content views.
    /// No insets are added by this. Set them yourself using the constants from `ChatViewConfiguration`.
    ///
    /// - Parameter rootView: Root view which will contain all content in it and it's subviews
    func addContent(rootView: UIView) {
        // This needs to be a subview of the `chatBubbleView` view instead of the `cell`
        // otherwise the bubble is drawn over this view and its subviews.
        chatBubbleView.addSubview(rootView)
        // Use `chatBubbleView` to get same margins as background bubble
        rootView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rootView.topAnchor.constraint(equalTo: chatBubbleView.topAnchor),
            rootView.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor),
            rootView.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor),
            rootView.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor),
        ])
    }
    
    /// Set the message that is displayed in this cell
    ///
    /// The message bubble will adapt to it.
    ///
    /// - Parameter message: Message that is shown in this cell
    func setMessage(to message: BaseMessage?) {
        self.message = message
    }

    // MARK: - Update
    
    override func updateColors() {
        super.updateColors()
        
        chatBubbleBackgroundView.backgroundColor = bubbleBackgroundColor
    }
    
    private func setLayoutForOwnMessage() {
        chatBubbleBackgroundView.showChatBubbleArrow = .trailing
        chatBubbleBackgroundView.backgroundColor = bubbleBackgroundColor

        NSLayoutConstraint.deactivate(otherMessageConstraints)
        NSLayoutConstraint.activate(ownMessageConstraints)
    }
    
    private func setLayoutForOtherMessage() {
        chatBubbleBackgroundView.showChatBubbleArrow = .leading
        chatBubbleBackgroundView.backgroundColor = bubbleBackgroundColor

        NSLayoutConstraint.deactivate(ownMessageConstraints)
        NSLayoutConstraint.activate(otherMessageConstraints)
    }
}

// MARK: - ChatScrollPositionDataProvider

extension ChatViewBaseTableViewCell: ChatScrollPositionDataProvider {
    var minY: CGFloat {
        frame.minY
    }

    var messageObjectID: NSManagedObjectID? {
        message?.objectID
    }

    var messageDate: Date? {
        message?.sectionDate
    }
}
