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
    
    // MARK: - Views & constraints

    private lazy var systemMessageTextLabel = SystemMessageTextLabel()
    
    private lazy var topSpacingConstraint = systemMessageTextLabel.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: ChatViewConfiguration.SystemMessage.defaultTopBottomInset
    )
    
    private lazy var bottomSpacingConstraint = systemMessageTextLabel.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -ChatViewConfiguration.SystemMessage.defaultTopBottomInset
    )

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        if UserSettings.shared().flippedTableView {
            contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        }
        
        isUserInteractionEnabled = false
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        
        defaultMinimalHeightConstraint.isActive = false
        
        contentView.addSubview(systemMessageTextLabel)
        systemMessageTextLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topSpacingConstraint,
            bottomSpacingConstraint,
            systemMessageTextLabel.widthAnchor
                .constraint(lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor),
            systemMessageTextLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        systemMessageTextLabel.updateCornerRadius()
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        systemMessageTextLabel.updateColors()
    }
    
    private func updateCell(for systemMessage: SystemMessage?) {
        guard case let .systemMessage(type: infoType) = systemMessage?.systemMessageType else {
            return
        }

        systemMessageTextLabel.text = infoType.localizedMessage
        systemMessageTextLabel.updateCornerRadius()
        
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
