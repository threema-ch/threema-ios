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
final class ChatViewWorkConsumerInfoSystemMessageTableViewCell: ThemedCodeTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewWorkConsumerInfoSystemMessageTableViewCell()
    
    /// System message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views.
    var systemMessage: SystemMessage? {
        didSet {
            updateCell(for: systemMessage)
        }
    }
    
    // MARK: - Views

    private lazy var systemMessageWorkConsumerLabel = SystemMessageWorkConsumerLabel()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        if UserSettings.shared().flippedTableView {
            contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        }

        isUserInteractionEnabled = false
        
        contentView.addSubview(systemMessageWorkConsumerLabel)
        systemMessageWorkConsumerLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            systemMessageWorkConsumerLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            systemMessageWorkConsumerLabel.bottomAnchor
                .constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            systemMessageWorkConsumerLabel.widthAnchor
                .constraint(lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor),
            systemMessageWorkConsumerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        systemMessageWorkConsumerLabel.updateCornerRadius()
        
        backgroundColor = .clear
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        systemMessageWorkConsumerLabel.updateColors()
    }
    
    private func updateCell(for systemMessage: SystemMessage?) {
        guard case let .workConsumerInfo(type: workConsumerType) = systemMessage?.systemMessageType else {
            return
        }
        systemMessageWorkConsumerLabel.type = workConsumerType
        systemMessageWorkConsumerLabel.updateCornerRadius()
    }
}

// MARK: - Reusable

extension ChatViewWorkConsumerInfoSystemMessageTableViewCell: Reusable { }

// MARK: - ChatScrollPositionDataProvider

extension ChatViewWorkConsumerInfoSystemMessageTableViewCell: ChatScrollPositionDataProvider {
    var minY: CGFloat {
        frame.minY
    }

    var messageObjectID: NSManagedObjectID? {
        systemMessage?.objectID
    }

    var messageDate: Date? {
        systemMessage?.sectionDate
    }
}

extension ChatViewWorkConsumerInfoSystemMessageTableViewCell {
    
    override public var accessibilityLabel: String? {
        get {
            guard let message = systemMessage else {
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
            guard let message = systemMessage,
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
            guard let message = systemMessage else {
                return .none
            }
            
            return message.customAccessibilityTrait
        }
        
        set {
            // No-op
        }
    }
}
