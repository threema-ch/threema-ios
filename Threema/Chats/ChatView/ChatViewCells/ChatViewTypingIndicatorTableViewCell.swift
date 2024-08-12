//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import UIKit

/// Cell for showing the typing indicator. It is modeled after the `ChatViewTextMessageTableViewCell` and adapts it's
/// height to a single line height text message cell.
final class ChatViewTypingIndicatorTableViewCell: ThemedCodeTableViewCell {
    private typealias Config = ChatViewConfiguration.TypingIndicator.View
    
    // MARK: - Private Properties
    
    /// Contains the message cell itself, plus the chatBubbleBackgroundView and is added to content view
    private lazy var chatBubbleView = UIView()
    
    private var chatBubbleBorderPath: UIBezierPath {
        chatBubbleBackgroundView.backgroundPath
    }
    
    /// Override this if you want to set a non-default width ratio
    private var bubbleWidthRatio: Double {
        ChatViewConfiguration.ChatBubble.defaultMaxWidthRatio
    }
    
    private lazy var typingIndicatorImageView = ChatViewTypingIndicatorImageView()
    
    private lazy var chatBubbleBackgroundView: ChatBubbleBackgroundView = {
        let backgroundView = ChatBubbleBackgroundView()
        backgroundView.showChatBubbleArrow = .bubbles
        return backgroundView
    }()
    
    private lazy var bubbleTopSpacingConstraint = chatBubbleView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: ChatViewConfiguration.ChatBubble.defaultTopBottomInset
    )
    
    private lazy var bubbleBottomSpacingConstraint = chatBubbleView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -ChatViewConfiguration.ChatBubble.defaultTopBottomInset
    )
    
    private lazy var otherMessageNoAvatarConstraints: [NSLayoutConstraint] = [
        chatBubbleBackgroundView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Config.leadingInsetConstant
        ),
    ]
    
    private var previousBoundsSize: CGRect?
    
    // MARK: - Overrides
    
    override var frame: CGRect {
        didSet {
            // When appearing together with the chat view `layoutSubviews` is not sufficient to
            // get the bounds of `messageTextViewSizeApproximationView`.
            typingIndicatorImageView.drawFrame = messageTextViewSizeApproximationView.bounds
            
            chatBubbleBackgroundView.bubbleFrame = chatBubbleView.bounds
        }
    }
    
    // MARK: - Views
    
    /// Used to approximate the size of a regular cell containing a text message
    private lazy var messageTextViewSizeApproximationView = MessageTextView(messageTextViewDelegate: nil)
    
    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        messageTextViewSizeApproximationView,
    ])
    
    private lazy var contentStackViewConstraints: [NSLayoutConstraint] = [
        contentStack.topAnchor.constraint(equalTo: containerView.topAnchor),
        contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    private lazy var containerView: UIView = {
        let view = UIView()
        
        // This adds the margin to the chat bubble border
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: -ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: -ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    // MARK: Configuration Functions
    
    override func configureCell() {
        super.configureCell()
        
        isUserInteractionEnabled = false
                
        // This removes the shadow cut-off of context menus and makes the avatars not cut-off by next cells
        clipsToBounds = false
        backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear
        
        // Configure cell layout
        // TODO: (IOS-2014) Maybe use backgroundView from cell?
        chatBubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chatBubbleView)
        
        chatBubbleBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        chatBubbleView.addSubview(chatBubbleBackgroundView)
        
        // TODO: (IOS-2943 & IOS-2489) Set correct layout guides for content view and test on iPad
        NSLayoutConstraint.activate([
            
            // Leading or trailing constraint for `chatBubbleView` is set by setLayoutFor... below
            bubbleTopSpacingConstraint,
            bubbleBottomSpacingConstraint,
            
            chatBubbleView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor,
                multiplier: bubbleWidthRatio
            ),
            
            // Add background to `chatBubbleView`
            chatBubbleBackgroundView.topAnchor.constraint(equalTo: chatBubbleView.topAnchor),
            chatBubbleBackgroundView.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor),
            chatBubbleBackgroundView.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor),
            chatBubbleBackgroundView.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor),
        ])
        
        NSLayoutConstraint.activate(otherMessageNoAvatarConstraints)
        
        messageTextViewSizeApproximationView.text = "3MA"
        messageTextViewSizeApproximationView.alpha = 0.0
        messageTextViewSizeApproximationView.translatesAutoresizingMaskIntoConstraints = false
        
        typingIndicatorImageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(messageTextViewSizeApproximationView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: messageTextViewSizeApproximationView.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: messageTextViewSizeApproximationView.bottomAnchor),
            containerView.trailingAnchor.constraint(equalTo: messageTextViewSizeApproximationView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: messageTextViewSizeApproximationView.topAnchor),
        ])
        
        containerView.addSubview(typingIndicatorImageView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: typingIndicatorImageView.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: typingIndicatorImageView.bottomAnchor),
            containerView.trailingAnchor.constraint(equalTo: typingIndicatorImageView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: typingIndicatorImageView.topAnchor),
        ])
        
        typingIndicatorImageView.animationRepeatCount = 0
        addContent(rootView: containerView)
    }
    
    func addContent(rootView: UIView) {
        
        // This needs to be a subview of the `chatBubbleView` view instead of the `cell`
        // otherwise the bubble is drawn over this view and its subviews.
        chatBubbleView.addSubview(rootView)
        
        // Use `chatBubbleView` to get same margins as background bubble
        rootView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rootView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor, constant: 0),
            rootView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor, constant: 0),
            rootView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor, constant: 0),
            rootView.layoutMarginsGuide.topAnchor.constraint(equalTo: chatBubbleView.topAnchor, constant: 0),
        ])
    }
    
    // MARK: - Update
    
    override func updateColors() {
        super.updateColors()
        
        chatBubbleBackgroundView.backgroundColor = Colors.chatBubbleReceived
        
        typingIndicatorImageView.updateColors()
    }
    
    // MARK: - Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        /// If our bounds change we re-render the typing animation
        guard previousBoundsSize != messageTextViewSizeApproximationView.bounds else {
            return
        }
        
        defer { self.previousBoundsSize = messageTextViewSizeApproximationView.bounds }
        
        typingIndicatorImageView.drawFrame = messageTextViewSizeApproximationView.bounds
        
        DDLogVerbose(
            "Rendering typing indicator for size \(bounds.size) - \(messageTextViewSizeApproximationView.bounds.size)"
        )
    }
    
    override func prepareForReuse() {
        // This is necessary on iOS 15 (maybe in other versions as well) because otherwise the animation would stop on
        // reuse.
        // It looks like UIImageView with an animated image isn't meant to be used in UITableView.
        typingIndicatorImageView.animationRepeatCount = 0
    }
}

extension ChatViewTypingIndicatorTableViewCell {
    
    override public var accessibilityLabel: String? {
        get {
            BundleUtil.localizedString(forKey: "accessibility_senderDescription_typing")
        }
        set {
            // No-op
        }
    }
}

// MARK: - Reusable

extension ChatViewTypingIndicatorTableViewCell: Reusable { }
