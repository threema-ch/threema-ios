//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import ThreemaMacros
import UIKit

/// Base class for all chat view cells with a chat bubble background
///
/// You should subclass this. If you use this directly it will only show a chat bubble.
///
/// When subclassing call `addContent(rootView:)` once to add the root view of your content views to the cell and set
/// `setMessage(to:)` whenever your message changes.
///
/// View hierarchy:
///
///                                         +-----------+
///                                         |contentView|
///                                         +-----^-----+
///                                               |
///                                               |
///                +------------------------------+-------------------------------+
///                |                              |                               |
///                |                              |                               |
///                |                              |                               |
///  +-------------+-----------+          +-------+------+               +--------+-------+
///  | chatBubbleBackgroundView|          |chatBubbleView|               |profilePictureView |
///  +-------------------------+          +------^-------+               +----------------+
///                                              |
///                                              |
///                                              |
///                                              +-------------------------------+
///                                              |                               |
///                                              |                               |
///                                              |                               |
///                                        +-----+----+                      +---+----+
///                                        | nameLabel|                      |rootView|
///                                        +----------+                      +--------+
///
class ChatViewBaseTableViewCell: ThemedCodeTableViewCell {
    
    // MARK: - Public properties
        
    /// Override this if you want to set a non-default distance constraint for the name label to the cell content
    var nameLabelBottomInset: Double {
        ChatViewConfiguration.GroupCells.nameLabelDefaultTopBottomInset
    }
    
    /// Suggestion if the cell should show date and state
    ///
    /// This is set after `setMessage(to:)` is called. Observe this value change (`didSet`) and adjust the visibility
    /// accordingly.
    var shouldShowDateAndState = true
    
    /// Override this if you want to set a non-default width ratio
    var bubbleWidthRatio: Double {
        ChatViewConfiguration.ChatBubble.defaultMaxWidthRatio
    }
    
    /// Background of chat bubble
    ///
    /// Override this if you want a non-default color background or no bubble at all.
    var bubbleBackgroundColor: UIColor {
        if let message = messageAndNeighbors.message, message.isOwnMessage {
            Colors.chatBubbleSent
        }
        else {
            Colors.chatBubbleReceived
        }
    }
    
    /// Selected background color of chat bubble
    ///
    /// Override this if you want a non-default selected background color or no bubble at all.
    var selectedBubbleBackgroundColor: UIColor {
        if let message = messageAndNeighbors.message, message.isOwnMessage {
            Colors.chatBubbleSentSelected
        }
        else {
            Colors.chatBubbleReceivedSelected
        }
    }
    
    /// Delegate used to handle cell delegates
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol? {
        didSet {
            if chatViewTableViewCellDelegate?.chatViewHasCustomBackground ?? false {
                profilePictureView.addBackground()
            }
        }
    }
    
    // MARK: Views and constraints
    
    /// Contains the message view (added in root view) & the `nameLabel`. It is added to `contentView`.
    private(set) lazy var chatBubbleView = {
        let chatBubbleView = ChatBubbleView { [weak self] _ in
            // On changing the bounds or the frame of chatBubbleView, we need to layout ourselves as well
            // to propagate the changes to the chatBubbleBackgroundView
            // The new value for the bubble of chatBubbleBackgroundView will be set in `layoutSubviews`
            self?.setNeedsLayout()
        }
       
        return chatBubbleView
    }()
    
    var chatBubbleBorderPath: UIBezierPath {
        chatBubbleBackgroundView.backgroundPath
    }
    
    /// Top spacing constraint
    ///
    /// Set the `constant` to another value if you don't want the default spacing used in the chat view. This might be
    /// overridden again after updating the message or its neighbors.
    private(set) lazy var bubbleTopSpacingConstraint = chatBubbleView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: ChatViewConfiguration.ChatBubble.defaultTopBottomInset
    )
    
    /// Bottom spacing constraint
    ///
    /// Set the `constant` to another value if you don't want the default spacing used in the chat view. This might be
    /// overridden again after updating the message or its neighbors.
    private(set) lazy var bubbleBottomSpacingConstraint = chatBubbleView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -ChatViewConfiguration.ChatBubble.defaultTopBottomInset
    )
    
    // MARK: - Internal state
    
    private let debugColors = false
    
    fileprivate var messageAndNeighbors: (message: BaseMessage?, neighbors: ChatViewDataSource.MessageNeighbors?) {
        didSet {
            guard let message = messageAndNeighbors.message else {
                return
            }
            
            if let oldMessage = oldValue.message, let newMessage = messageAndNeighbors.message,
               oldMessage.objectID == newMessage.objectID {
                // We are reconfiguring this cell (or conveniently reusing our own cell) which means animations will
                // look good i.e. elements won't come flying in from the side
                chatBubbleBackgroundView.animate = true
            }
            else {
                // We are most likely a new cell and don't animate our content configuration or update
                chatBubbleBackgroundView.animate = false
            }
            
            if message.isOwnMessage {
                setLayoutForOwnMessage()
                hideNameLabel()
            }
            else {
                setLayoutForOtherMessage()
            }

            updateRetryAndCancelButton()
            updateColors()
            
            if debugColors, let neighbors = messageAndNeighbors.neighbors {
                if neighbors.previousMessage == nil,
                   neighbors.nextMessage == nil {
                    contentView.backgroundColor = .systemGray
                }
                else if neighbors.previousMessage != nil,
                        neighbors.nextMessage == nil {
                    contentView.backgroundColor = .systemYellow
                }
                else if neighbors.previousMessage == nil,
                        neighbors.nextMessage != nil {
                    contentView.backgroundColor = .systemGreen
                }
                else if neighbors.previousMessage != nil,
                        neighbors.nextMessage != nil {
                    contentView.backgroundColor = .systemRed
                }
            }
        }
    }
    
    private lazy var tappedProfilePictureGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(profilePictureTapped)
    )
    
    // MARK: Views
    
    private lazy var chatBubbleBackgroundView = ChatBubbleBackgroundView()
    
    private lazy var retryAndCancelButton = BlurCircleButton(
        sfSymbolName: "play.fill",
        accessibilityLabel: "",
        configuration: .retryAndCancel
    ) { [weak self] _ in
        self?.retryOrCancel()
    }
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0

        label.font = ChatViewConfiguration.GroupCells.nameLabelFont
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()
    
    private lazy var profilePictureView: ProfilePictureImageView = {
        let profilePictureView = ProfilePictureImageView()
        profilePictureView.isUserInteractionEnabled = true
        profilePictureView.addGestureRecognizer(tappedProfilePictureGestureRecognizer)
        profilePictureView.isAccessibilityElement = false
        
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        
        profilePictureView.widthAnchor.constraint(
            equalToConstant: UIFontMetrics.default
                .scaledValue(for: ChatViewConfiguration.GroupCells.maxProfilePictureSize)
        ).isActive = true
        
        return profilePictureView
    }()
    
    // MARK: Constraints
    
    private lazy var nameConstraints = [NSLayoutConstraint]()
    private lazy var noNameConstraints = [NSLayoutConstraint]()
    
    private lazy var ownMessageConstraints: [NSLayoutConstraint] = [
        chatBubbleView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -ChatViewConfiguration.ChatBubble.defaultLeadingTrailingInset
        ),
        retryAndCancelButton.trailingAnchor.constraint(
            equalTo: chatBubbleView.leadingAnchor,
            constant: -ChatViewConfiguration.ChatBubble.RetryAndCancelButton.buttonChatBubbleSpacing
        ),
        retryAndCancelButton.centerYAnchor.constraint(equalTo: chatBubbleView.centerYAnchor),
    ]
    
    private lazy var otherMessageNoProfilePictureConstraints: [NSLayoutConstraint] = [
        chatBubbleView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: ChatViewConfiguration.ChatBubble.defaultLeadingTrailingInset
        ),
    ]
    
    private lazy var otherMessageProfilePictureConstraints: [NSLayoutConstraint] =
        [chatBubbleView.leadingAnchor.constraint(
            equalTo: profilePictureView.trailingAnchor,
            constant: ChatViewConfiguration.GroupCells.profilePictureCellSpace
        )]
        
    // These are always active
    private lazy var profilePictureViewConstraints: [NSLayoutConstraint] = [
        profilePictureView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: ChatViewConfiguration.GroupCells.profilePictureLeadingInset
        ),
        profilePictureView.centerYAnchor.constraint(
            equalTo: chatBubbleView.bottomAnchor,
            constant: -max(
                UIFontMetrics.default.scaledValue(for: ChatViewConfiguration.GroupCells.profilePictureVerticalOffset),
                ChatViewConfiguration.GroupCells.profilePictureVerticalOffset
            )
        ),
    ]
       
    /// Handles all horizontal swipe interactions including cancelling other swipe actions via
    /// `ChatViewTableViewCellDelegateProtocol`
    private var swipeHandler: ChatViewTableViewCellHorizontalSwipeHandler?
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        configureBackgrounds()
        configureViewsAndLayout()
        
        // For a default configuration without missing constraints
        setLayoutForOtherMessage()
        
        swipeHandler = ChatViewTableViewCellHorizontalSwipeHandler(
            cell: self,
            delegate: self
        )
    }
    
    private func configureBackgrounds() {
        // We want a clear backgrounds (also when highlighted and selected)
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        
        // This removes the shadow cut-off of context menus and makes the profile picture not cut-off by next cells
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    private func configureViewsAndLayout() {
        // TODO: (IOS-2014) Maybe use backgroundView from cell?
        
        // Add views
        contentView.addSubview(chatBubbleBackgroundView)
        chatBubbleBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(chatBubbleView)
        chatBubbleView.translatesAutoresizingMaskIntoConstraints = false
        
        chatBubbleView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        // By default the name is hidden
        nameLabel.isHidden = true
        
        contentView.addSubview(profilePictureView)
      
        contentView.addSubview(retryAndCancelButton)
        retryAndCancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure layout
        
        // If date and state is hidden the cell height might be below 44 pt
        defaultMinimalHeightConstraint.isActive = false
        
        // TODO: (IOS-2943 & IOS-2489) Set correct layout guides for content view and test on iPad
        NSLayoutConstraint.activate([
            // Leading or trailing constraint for `chatBubbleView` is set by setLayoutFor... below
            bubbleTopSpacingConstraint,
            bubbleBottomSpacingConstraint,
            
            chatBubbleView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor,
                multiplier: bubbleWidthRatio
            ),
            
            // Add background of `chatBubbleView` to `contentView`
            chatBubbleBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            chatBubbleBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chatBubbleBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            chatBubbleBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        
        NSLayoutConstraint.activate(profilePictureViewConstraints)
        
        isAccessibilityElement = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // This will animate depending on whether the message that was set in `messageAndNeighbors`
        // has changed.
        chatBubbleBackgroundView.bubbleFrame = chatBubbleView.frame
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
        rootView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use `chatBubbleView` to get same margins as background bubble
        NSLayoutConstraint.activate([
            // Top constraints depends on name constraint
            rootView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor),
            rootView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor),
            rootView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor),
        ])
        
        // Configure name constraints
        
        nameConstraints = [
            nameLabel.topAnchor.constraint(
                equalTo: chatBubbleView.topAnchor,
                constant: ChatViewConfiguration.Content.defaultTopBottomInset
            ),
            nameLabel.leadingAnchor.constraint(
                equalTo: chatBubbleView.leadingAnchor,
                constant: ChatViewConfiguration.Content.defaultLeadingTrailingInset
            ),
            nameLabel.bottomAnchor.constraint(
                equalTo: rootView.topAnchor,
                constant: -nameLabelBottomInset
            ),
            nameLabel.trailingAnchor.constraint(
                equalTo: chatBubbleView.trailingAnchor,
                constant: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
            ),
        ]
        
        noNameConstraints = [
            rootView.layoutMarginsGuide.topAnchor.constraint(equalTo: chatBubbleView.topAnchor),
        ]
        
        NSLayoutConstraint.activate(noNameConstraints)
        
        // We disable the accessibility of the rootView and its children and implement it in our own way below
        rootView.isAccessibilityElement = false
        rootView.accessibilityTraits = .none
    }
    
    /// Set the message and its neighbors displayed in this cell
    ///
    /// The message bubble will adapt to it.
    ///
    /// - Parameter message: Message that is shown in this cell. Set to `nil` to reset the cell.
    /// - Parameter neighbors: The messages that immediately preceded and succeeded `message` when the conversations
    ///                        messages are sorted as displayed in the chat. Should be `nil` if `message` is `nil`.
    func setMessage(to message: BaseMessage?, with neighbors: ChatViewDataSource.MessageNeighbors?) {
        if message == nil, neighbors != nil {
            DDLogWarn("Neighbors should have a message")
        }
        messageAndNeighbors = (message, neighbors)
    }
    
    // MARK: - Update
        
    override func updateColors() {
        super.updateColors()
        
        chatBubbleBackgroundView.backgroundColor = bubbleBackgroundColor
        updateNameLabelColor()
        swipeHandler?.updateColors()
    }
    
    private func updateNameLabelColor() {
        let nameLabelColor = messageAndNeighbors.message?.sender?.idColor ?? .primary
        nameLabel.textColor = nameLabelColor
        nameLabel.highlightedTextColor = nameLabelColor
    }
    
    func blinkCell(duration: Double, feedback: Bool = true, completeCell: Bool = true) {
        
        // Haptic feedback
        if feedback {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        
        // Highlight cell
        if completeCell {
            highlightCompleteCell(true)
        }
        else {
            highlightTappableAreasOfCell(true)
        }
        
        // Revert after delay
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + duration
        ) {
            if completeCell {
                self.highlightCompleteCell(false)
            }
            else {
                self.highlightTappableAreasOfCell(false)
            }
        }
    }
    
    /// Updates colors for complete cell depending on the indicated highlight state.
    ///
    /// This does not change the `isHighlighted` of the cell and its subviews.
    ///
    /// - Parameter highlight: Highlight or unhighlight cell
    func highlightCompleteCell(_ highlight: Bool) {
        UIView.animate(
            withDuration: ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightFadeInOutDuration,
            delay: .zero,
            options: .curveEaseInOut
        ) { [weak self] in
            if highlight {
                self?.chatBubbleBackgroundView.backgroundColor = self?.selectedBubbleBackgroundColor
            }
            else {
                self?.chatBubbleBackgroundView.backgroundColor = self?.bubbleBackgroundColor
            }
        }
    }
    
    /// Updates colors of the tappable areas of a cell depending on the indicated highlight state.
    ///
    /// By default highlights the complete cell, override this method if you need custom behavior.
    /// This does not change the `isHighlighted` of the cell and its subviews.
    ///
    /// - Parameter highlight: Highlight or unhighlight tappable area of cell
    func highlightTappableAreasOfCell(_ highlight: Bool) {
        highlightCompleteCell(highlight)
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        guard isSelected != selected else {
            return
        }
        
        super.setSelected(selected, animated: animated)
        highlightCompleteCell(selected)
    }
        
    override func setEditing(_ editing: Bool, animated: Bool) {
        guard isEditing != editing else {
            return
        }
        
        super.setEditing(editing, animated: animated)
        
        profilePictureView.isUserInteractionEnabled = !editing
    }
    
    func updateRetryAndCancelButton() {
        
        guard let fileMessage = messageAndNeighbors.message as? BlobData,
              let symbolName = fileMessage.blobDisplayState.symbolName else {
            retryAndCancelButton.updateSymbol(to: ChatViewConfiguration.ChatBubble.RetryAndCancelButton.symbolName)
            return
        }
        
        retryAndCancelButton.updateSymbol(to: symbolName)
    }
    
    // MARK: - Update layout & views
    
    // Workaround: Only the top insets change
    //
    // If the previous last message cell height changes when a new message is inserted it jumps. To prevent
    // a height change of the existing message (previously last message) we only change the top inset of cells and
    // keep the bottom inset constant. So the newly arrived messages can set the correct top inset and the other cells
    // don't have to adapt.
    //
    // This enables smooth animations when new messages arrive (and you're scrolled to the bottom).
    //
    // Caveats:
    //   1. In group chat the profile picture of the sender is shortly cut off at the bottom when the new message is
    //      animated in. For a future workaround see below. (IOS-2943)
    //   2. The calculation of the top offsets are somewhat complicated.
    //
    // Ideally we would set the appropriate inset on top and bottom of each cell. For this we have to figure out if
    // we can nicely animate cell height changes. (IOS-2943)
    
    private func setLayoutForOwnMessage() {
        profilePictureView.isHidden = true
        
        retryAndCancelButton.isHidden = !(messageAndNeighbors.message?.showRetryAndCancelButton ?? false)
               
        NSLayoutConstraint.deactivate(otherMessageNoProfilePictureConstraints)
        NSLayoutConstraint.deactivate(otherMessageProfilePictureConstraints)
        NSLayoutConstraint.activate(ownMessageConstraints)
        
        // The `isGroup` is needed as long the top and bottom margins are not equal around system messages
        let isGroup = messageAndNeighbors.message?.isGroupMessage ?? false
        
        setUpdatedInsets(isGroup: isGroup)
        
        // Bubble arrow
        if shouldGroupWithNextMessage {
            chatBubbleBackgroundView.showChatBubbleArrow = .none
        }
        else {
            chatBubbleBackgroundView.showChatBubbleArrow = .trailing
        }
    }
    
    private func setLayoutForOtherMessage() {
        let isGroup = messageAndNeighbors.message?.isGroupMessage ?? false
        
        retryAndCancelButton.isHidden = true

        // Set base layout
        if isGroup {
            setLayoutForOtherMessageInGroup()
        }
        else {
            setLayoutForOtherMessageNoGroup()
        }
        
        setUpdatedInsets(isGroup: isGroup)
        
        // Bubble arrow
        if shouldGroupWithNextMessage {
            chatBubbleBackgroundView.showChatBubbleArrow = .none
        }
        else {
            chatBubbleBackgroundView.showChatBubbleArrow = .leading
        }
    }
    
    private func setUpdatedInsets(isGroup: Bool = false) {
        // See workaround above for details about why the insets are set this way
        
        // Top insets: Add everything needed expect in certain cases
        if shouldUseDefaultTopInset {
            if isGroup {
                bubbleTopSpacingConstraint.constant = ChatViewConfiguration.ChatBubble.defaultGroupTopBottomInset
            }
            else {
                bubbleTopSpacingConstraint.constant = ChatViewConfiguration.ChatBubble.defaultTopBottomInset
            }
        }
        else if shouldGroupWithPreviousMessage {
            bubbleTopSpacingConstraint.constant = ChatViewConfiguration.ChatBubble.groupedTopBottomInset
        }
        else {
            if isGroup {
                bubbleTopSpacingConstraint.constant = (2 * ChatViewConfiguration.ChatBubble.defaultGroupTopBottomInset)
                    // Remove the minimal bottom inset
                    - ChatViewConfiguration.ChatBubble.groupedTopBottomInset
            }
            else {
                bubbleTopSpacingConstraint.constant = (2 * ChatViewConfiguration.ChatBubble.defaultTopBottomInset)
                    // Remove the minimal bottom inset
                    - ChatViewConfiguration.ChatBubble.groupedTopBottomInset
            }
        }
        
        // Bottom insets: Normally set to the minimum we always have. Some cells may indicate that the default bottom
        // inset should be used
        if shouldUseDefaultBottomInset {
            if isGroup {
                bubbleBottomSpacingConstraint.constant = -ChatViewConfiguration.ChatBubble.defaultGroupTopBottomInset
            }
            else {
                bubbleBottomSpacingConstraint.constant = -ChatViewConfiguration.ChatBubble.defaultTopBottomInset
            }
        }
        else {
            bubbleBottomSpacingConstraint.constant = -ChatViewConfiguration.ChatBubble.groupedTopBottomInset
        }
        
        // Date and state
        if ChatViewConfiguration.CellGrouping.enableDateAndStateGrouping {
            if shouldGroupWithNextMessage {
                shouldShowDateAndState = !nextMessageHasSameDateAndState
            }
            else {
                shouldShowDateAndState = true
            }
        }
        else {
            shouldShowDateAndState = true
        }
    }
    
    /// Don't call this directly. Use `setLayoutForOtherMessage()`.
    private func setLayoutForOtherMessageNoGroup() {
        // Not a group, we hide the name and the profile picture and set normal constraints
        hideNameLabel()

        profilePictureView.isHidden = true

        NSLayoutConstraint.deactivate(ownMessageConstraints)
        NSLayoutConstraint.deactivate(otherMessageProfilePictureConstraints)
        NSLayoutConstraint.activate(otherMessageNoProfilePictureConstraints)
    }
    
    /// Don't call this directly. Use `setLayoutForOtherMessage()`.
    private func setLayoutForOtherMessageInGroup() {
        // If the conversation is a group, we set the name label if it is the first message, and we generally apply
        // constraints for profile picture
        
        // Name label on first message
        if !shouldGroupWithPreviousMessage {
            nameLabel.text = messageAndNeighbors.message?.sender?.displayName
            updateNameLabelColor()
            showNameLabel()
        }
        else {
            hideNameLabel()
        }
        
        // Profile picture on last message
        if !shouldGroupWithNextMessage {
            updateProfilePicture()
            profilePictureView.isHidden = false
        }
        else {
            profilePictureView.isHidden = true
        }
        
        // Image Constraints
        NSLayoutConstraint.deactivate(ownMessageConstraints)
        NSLayoutConstraint.deactivate(otherMessageNoProfilePictureConstraints)
        NSLayoutConstraint.activate(otherMessageProfilePictureConstraints)
    }
    
    // MARK: Name label
    
    private func showNameLabel() {
        guard nameLabel.isHidden else {
            return
        }
        
        nameLabel.isHidden = false
        NSLayoutConstraint.deactivate(noNameConstraints)
        NSLayoutConstraint.activate(nameConstraints)
    }
    
    private func hideNameLabel() {
        guard !nameLabel.isHidden else {
            return
        }
        
        nameLabel.isHidden = true
        NSLayoutConstraint.deactivate(nameConstraints)
        NSLayoutConstraint.activate(noNameConstraints)
    }
    
    // MARK: Profile picture
    
    private func updateProfilePicture() {
        guard let sender = messageAndNeighbors.message?.sender else {
            profilePictureView.info = .contact(nil)
            return
        }
        profilePictureView.info = .contact(Contact(contactEntity: sender))
    }
    
    // MARK: - Actions
    
    @objc private func profilePictureTapped() {
        guard let sender = messageAndNeighbors.message?.sender else {
            return
        }
        
        chatViewTableViewCellDelegate?.show(identity: sender.identity)
    }
    
    private func retryOrCancel() {
    
        guard let message = messageAndNeighbors.message else {
            return
        }
    
        chatViewTableViewCellDelegate?.retryOrCancelSendingMessage(withID: message.objectID, from: retryAndCancelButton)
    }

    // MARK: - Neighboring helpers
        
    private var shouldGroupWithPreviousMessage: Bool {
        guard let previousMessage = messageAndNeighbors.neighbors?.previousMessage,
              let message = messageAndNeighbors.message else {
            return false
        }
        
        return shouldGroupMessage(previousMessage, with: message)
    }
        
    private var shouldGroupWithNextMessage: Bool {
        guard let message = messageAndNeighbors.message,
              let nextMessage = messageAndNeighbors.neighbors?.nextMessage else {
            return false
        }
        
        return shouldGroupMessage(message, with: nextMessage)
    }
    
    private func shouldGroupMessage(_ lhs: BaseMessage, with rhs: BaseMessage) -> Bool {
        // TODO: (IOS-2943) Do we have to check if one is a system message...?
        
        // It needs to have the same sender
        if lhs.isGroupMessage { // We assume both messages are in the same conversation
            // Either the sender should be identical in a group or both messages should be ours
            if let lhsMessageIdentity = lhs.sender?.identity,
               let rhsMessageIdentity = rhs.sender?.identity {
                guard rhsMessageIdentity == lhsMessageIdentity else {
                    return false
                }
            }
            else {
                guard lhs.isOwnMessage, rhs.isOwnMessage else {
                    return false
                }
            }
        }
        else { // In one-to-one conversations we check if both messages are our own or not
            guard lhs.isOwnMessage == rhs.isOwnMessage else {
                return false
            }
        }
        
        // It needs to be in the same day
        guard Calendar.current.isDate(lhs.sectionDate, inSameDayAs: rhs.sectionDate) else {
            return false
        }
        
        // It needs to be in the predefined interval
        guard abs(
            rhs.sectionDate.timeIntervalSinceReferenceDate - lhs.sectionDate
                .timeIntervalSinceReferenceDate
        )
            < ChatViewConfiguration.CellGrouping.maxDurationForGroupingTogether else {
            return false
        }
        
        return true
    }
    
    private var nextMessageHasSameDateAndState: Bool {
        guard let message = messageAndNeighbors.message,
              let nextMessage = messageAndNeighbors.neighbors?.nextMessage else {
            return false
        }
        
        // Same date?
        guard Calendar.current.isDate(message.displayDate, equalTo: nextMessage.displayDate, toGranularity: .minute)
        else {
            return false
        }
        
        // Same state?
        guard message.messageDisplayState == nextMessage.messageDisplayState else {
            return false
        }
        
        // Is the state not .failed?
        guard message.messageDisplayState != .failed else {
            return false
        }
        
        // Has reactions?
        if (message.messageDisplayState == .userAcknowledged || message.messageDisplayState == .userDeclined) ||
            (message.isGroupMessage && message.messageGroupReactionState != .none) {
            return false
        }
        
        // Do we have any markers?
        guard !message.hasMarkers else {
            return false
        }

        // Is edited message?
        guard message.lastEditedAt == nil else {
            return false
        }

        return true
    }
    
    // MARK: Helpers to compensate for non-equal top and bottom insets
    
    // You probably only need one of these:
    
    private var shouldUseDefaultTopInset: Bool {
        previousMessageIsSystemMessage || !previousMessageIsInSameDay
    }
    
    private var shouldUseDefaultBottomInset: Bool {
        nextMessageIsSystemMessage || !nextMessageIsInSameDay
    }
    
    // Helpers for the helpers
    
    private var previousMessageIsSystemMessage: Bool {
        guard let systemMessage = messageAndNeighbors.neighbors?.previousMessage as? SystemMessageEntity else {
            return false
        }
        
        switch systemMessage.systemMessageType {
        case .systemMessage:
            return true
        case .callMessage, .workConsumerInfo:
            return false
        }
    }
    
    private var previousMessageIsInSameDay: Bool {
        guard let previousMessage = messageAndNeighbors.neighbors?.previousMessage,
              let message = messageAndNeighbors.message else {
            return true
        }
        
        return Calendar.current.isDate(previousMessage.sectionDate, inSameDayAs: message.sectionDate)
    }
    
    private var nextMessageIsSystemMessage: Bool {
        guard let systemMessage = messageAndNeighbors.neighbors?.nextMessage as? SystemMessageEntity else {
            return false
        }
        
        switch systemMessage.systemMessageType {
        case .systemMessage:
            return true
        case .callMessage, .workConsumerInfo:
            return false
        }
    }
    
    private var nextMessageIsInSameDay: Bool {
        guard let nextMessage = messageAndNeighbors.neighbors?.nextMessage,
              let message = messageAndNeighbors.message else {
            return true
        }
        
        return Calendar.current.isDate(nextMessage.sectionDate, inSameDayAs: message.sectionDate)
    }
}

// MARK: - ChatScrollPositionDataProvider

extension ChatViewBaseTableViewCell: ChatScrollPositionDataProvider {
    var minY: CGFloat {
        frame.minY
    }
    
    var messageObjectID: NSManagedObjectID? {
        messageAndNeighbors.message?.objectID
    }
    
    var messageDate: Date? {
        messageAndNeighbors.message?.sectionDate
    }
}

// MARK: - ChatViewTableViewCellHorizontalSwipeHandlerDelegate

extension ChatViewBaseTableViewCell: ChatViewTableViewCellHorizontalSwipeHandlerDelegate {
    func swipe(with recognizer: UIPanGestureRecognizer) {
        chatViewTableViewCellDelegate?.swipeMessageTableViewCell(
            swipeMessageTableViewCell: self,
            recognizer: recognizer
        )
    }
    
    var canQuote: Bool {
        (messageAndNeighbors.message is QuoteMessage) &&
            messageAndNeighbors.message?.deletedAt == nil &&
            (chatViewTableViewCellDelegate?.cellInteractionEnabled ?? false) &&
            !(chatViewTableViewCellDelegate?.chatViewIsDistributionListConversation ?? false)
    }
    
    func showQuoteView() {
        guard let message = messageAndNeighbors.message as? QuoteMessage else {
            DDLogError(
                "Cannot show quote as message is nil (\(messageAndNeighbors.message == nil) or not a QuoteMessage"
            )
            return
        }
        chatViewTableViewCellDelegate?.showQuoteView(message: message)
    }
    
    func configure(swipeGestureRecognizer: UIPanGestureRecognizer) {
        chatViewTableViewCellDelegate?.configure(swipeGestureRecognizer: swipeGestureRecognizer)
    }
}

// MARK: - Accessibility

extension ChatViewBaseTableViewCell {
    
    override public var accessibilityLabel: String? {
        get {
            guard let message = messageAndNeighbors.message as? MessageAccessibility else {
                return nil
            }
            var status = ""
            
            // We add the status, if the voice message is playing.
            if let voiceCell = self as? ChatViewVoiceMessageTableViewCell,
               voiceCell.isPlaying {
                status = #localize("accessibility_voice_message_playing")
            }
            
            var quote = ""
            if let quotedMessage = message as? QuoteMessageProvider,
               let quoteMessage = quotedMessage.quoteMessage {
                quote =
                    "\(#localize("in_reply_to")) \(quoteMessage.accessibilitySenderAndMessageTypeText) \(quoteMessage.previewText)."
            }

            let editedMessage = message.lastEditedAt != nil ? BundleUtil
                .localizedString(forKey: "edited_message_state") : ""

            let labelText =
                "\(message.accessibilitySenderAndMessageTypeText) \(status) \(message.customAccessibilityLabel) \(quote) \(editedMessage) \(message.accessibilityDateAndState)"
            return labelText
        }
        
        set {
            // No-op
        }
    }
    
    override var accessibilityValue: String? {
        get {
            guard let message = messageAndNeighbors.message as? MessageAccessibility else {
                return .none
            }
            
            return message.customAccessibilityValue
        }
        
        set {
            // No-op
        }
    }
    
    override public var accessibilityHint: String? {
        get {
            guard let message = messageAndNeighbors.message as? MessageAccessibility,
                  let accessibilityHint = message.customAccessibilityHint else {
                return nil
            }
            return accessibilityHint
        }
        
        set {
            // No-op
        }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            guard let message = messageAndNeighbors.message as? MessageAccessibility else {
                return .none
            }
            
            return message.customAccessibilityTrait
        }
        
        set {
            // No-op
        }
    }
    
    override func accessibilityActivate() -> Bool {
        guard let message = messageAndNeighbors.message, !(self is ChatViewVoiceMessageTableViewCell) else {
            return false
        }
        
        chatViewTableViewCellDelegate?.didTap(message: message, in: self)
        chatViewTableViewCellDelegate?.didAccessibilityTapOnCell()
        return true
    }
}

extension ChatViewBaseTableViewCell {
    var currentSearchText: String? {
        guard let chatViewTableViewCellDelegate else {
            return nil
        }
        return chatViewTableViewCellDelegate.currentSearchText
    }
}
