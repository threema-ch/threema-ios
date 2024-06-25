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

import ThreemaFramework
import UIKit

/// Display a system message
final class ChatViewSystemMessageTableViewCell: ThemedCodeTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewSystemMessageTableViewCell()
    
    /// System message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views.
    var systemMessageAndNeighbors: (message: SystemMessage?, neighbors: ChatViewDataSource.MessageNeighbors?) {
        didSet {
            updateCell(for: systemMessageAndNeighbors.message)
        }
    }
    
    /// Delegate used to handle cell delegates
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol?
    
    // MARK: - Private properties
    
    private lazy var markupParser = MarkupParser()
    
    // MARK: Views & constraints
    
    private lazy var systemMessageLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        
        label.font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.SystemMessageText.defaultTextStyle)
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    private lazy var systemMessageBackgroundView: UIView = {
        let view = UIView()
        
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            leading: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset,
            bottom: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            trailing: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset
        )
        
        view.layer.cornerCurve = .continuous
        
        return view
    }()
    
    private lazy var topSpacingConstraint = systemMessageBackgroundView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: ChatViewConfiguration.SystemMessage.defaultTopBottomInset
    )
    
    private lazy var bottomSpacingConstraint = systemMessageBackgroundView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -ChatViewConfiguration.SystemMessage.defaultTopBottomInset
    )

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        
        // Layout
        
        defaultMinimalHeightConstraint.isActive = false

        // The label is a subview of the background view
        contentView.addSubview(systemMessageBackgroundView)
        systemMessageBackgroundView.addSubview(systemMessageLabel)
        
        systemMessageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        systemMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topSpacingConstraint,
            bottomSpacingConstraint,
            
            systemMessageBackgroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            systemMessageBackgroundView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor
            ),
            
            systemMessageBackgroundView.layoutMarginsGuide.topAnchor.constraint(
                equalTo: systemMessageLabel.topAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.leadingAnchor.constraint(
                equalTo: systemMessageLabel.leadingAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.bottomAnchor.constraint(
                equalTo: systemMessageLabel.bottomAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.trailingAnchor.constraint(
                equalTo: systemMessageLabel.trailingAnchor
            ),
        ])
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        systemMessageLabel.textColor = Colors.textLight
        systemMessageLabel.highlightedTextColor = Colors.textLight
        systemMessageBackgroundView.backgroundColor = Colors.systemMessageBackground
    }
    
    private func updateCell(for systemMessage: SystemMessage?) {
        guard case let .systemMessage(type: infoType) = systemMessage?.systemMessageType else {
            return
        }
        
        systemMessageLabel.attributedText = markupParser.markify(
            attributedString: NSAttributedString(string: infoType.localizedMessage),
            font: UIFont.preferredFont(forTextStyle: ChatViewConfiguration.SystemMessageText.defaultTextStyle),
            parseURL: false,
            parseMention: false,
            removeMarkups: true
        )
        
        // Adjust insets depending on the neighbors
        
        if shouldGroupWithPreviousSystemMessage {
            topSpacingConstraint.constant = ChatViewConfiguration.SystemMessage.groupedDefaultTopBottomInset
        }
        else {
            topSpacingConstraint.constant = ChatViewConfiguration.SystemMessage.defaultTopBottomInset
        }
        
        if shouldGroupWithNextSystemMessage {
            bottomSpacingConstraint.constant = -ChatViewConfiguration.SystemMessage.groupedDefaultTopBottomInset
        }
        else {
            bottomSpacingConstraint.constant = -ChatViewConfiguration.SystemMessage.defaultTopBottomInset
        }
        
        updateColors()
    }
    
    // MARK: - Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure that we always have a correct corner radius
        var newCornerRadius = min(
            ChatViewConfiguration.SystemMessage.Background.cornerRadius,
            systemMessageBackgroundView.frame.height / 2
        )
        
        // We sometimes ran into an issue where the frame height was 0 on initial loading in iOS 15.6.
        if newCornerRadius == 0 {
            newCornerRadius = ChatViewConfiguration.SystemMessage.Background.cornerRadius
        }
        
        systemMessageBackgroundView.layer.cornerRadius = newCornerRadius
    }
    
    // MARK: - Neighboring helpers
    
    // You should only need these two:
    
    private var shouldGroupWithPreviousSystemMessage: Bool {
        previousMessageIsSystemMessage && previousMessageIsInSameDay
    }
    
    private var shouldGroupWithNextSystemMessage: Bool {
        nextMessageIsSystemMessage && nextMessageIsInSameDay
    }
    
    // Helper for the helpers
    
    private var previousMessageIsSystemMessage: Bool {
        guard let systemMessage = systemMessageAndNeighbors.neighbors?.previousMessage as? SystemMessage else {
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
        guard let previousMessage = systemMessageAndNeighbors.neighbors?.previousMessage,
              let message = systemMessageAndNeighbors.message else {
            return true
        }
        
        return Calendar.current.isDate(previousMessage.sectionDate, inSameDayAs: message.sectionDate)
    }
        
    private var nextMessageIsSystemMessage: Bool {
        guard let systemMessage = systemMessageAndNeighbors.neighbors?.nextMessage as? SystemMessage else {
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
        guard let nextMessage = systemMessageAndNeighbors.neighbors?.nextMessage,
              let message = systemMessageAndNeighbors.message else {
            return true
        }
        
        return Calendar.current.isDate(nextMessage.sectionDate, inSameDayAs: message.sectionDate)
    }
}

// MARK: - Reusable

extension ChatViewSystemMessageTableViewCell: Reusable { }

// MARK: - ChatScrollPositionDataProvider

extension ChatViewSystemMessageTableViewCell: ChatScrollPositionDataProvider {
    var minY: CGFloat {
        frame.minY
    }

    var messageObjectID: NSManagedObjectID? {
        systemMessageAndNeighbors.message?.objectID
    }

    var messageDate: Date? {
        systemMessageAndNeighbors.message?.sectionDate
    }
}

// MARK: - Accessibility

extension ChatViewSystemMessageTableViewCell {
    
    override public var accessibilityLabel: String? {
        get {
            guard let message = systemMessageAndNeighbors.message else {
                return nil
            }
            return message.customAccessibilityLabel
        }
        
        set {
            // No-op
        }
    }
    
    override public var accessibilityHint: String? {
        get {
            guard let message = systemMessageAndNeighbors.message,
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
            guard let message = systemMessageAndNeighbors.message else {
                return .none
            }
            
            return message.customAccessibilityTrait
        }
        
        set {
            // No-op
        }
    }
}

// MARK: - ChatViewMessageAction

extension ChatViewSystemMessageTableViewCell: ChatViewMessageAction {
    
    func messageActions()
        -> (
            primaryActions: [ChatViewMessageActionProvider.MessageAction],
            generalActions: [ChatViewMessageActionProvider.MessageAction]
        )? {

        guard let message = systemMessageAndNeighbors.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionProvider
        var menuItems = [ChatViewMessageActionProvider.MessageAction]()
        
        let detailAction = Provider.detailsAction {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Delete
        let willDelete = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        let deleteAction = Provider.deleteAction(
            message: message,
            willDelete: willDelete,
            didDelete: didDelete,
            popOverSource: systemMessageBackgroundView
        )
        
        menuItems.append(contentsOf: [detailAction, deleteAction])
        
        return ([ChatViewMessageActionProvider.MessageAction](), menuItems)
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
