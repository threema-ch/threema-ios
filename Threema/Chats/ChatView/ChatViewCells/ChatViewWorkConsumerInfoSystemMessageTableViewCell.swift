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

/// Displays the work/consumer info at the beginning of chats with the other type
final class ChatViewWorkConsumerInfoSystemMessageTableViewCell: ThemedCodeTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewWorkConsumerInfoSystemMessageTableViewCell()
    
    /// System message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views.
    var systemMessage: SystemMessage? {
        didSet {
            updateCell(for: systemMessage)
            updateColors()
        }
    }

    // MARK: Views & constraints
    
    private lazy var systemMessageWorkConsumerLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.font = ChatViewConfiguration.SystemMessageText.workConsumerFont
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    private lazy var systemMessageWorkConsumerImageView: UIImageView = {
        let imageView = UIImageView()
        let scaledFontSize = UIFontMetrics.default
            .scaledValue(for: ChatViewConfiguration.SystemMessageText.workConsumerFont.capHeight) * 1.75
        imageView.widthAnchor.constraint(equalToConstant: scaledFontSize).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: scaledFontSize).isActive = true

        imageView.clipsToBounds = true
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var systemMessageBackgroundView: UIView = {
        let view = UIView()
        
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            leading: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset / 2,
            bottom: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            trailing: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset
        )
                
        view.layer.cornerCurve = .continuous
        
        return view
    }()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        if UserSettings.shared().flippedTableView {
            transform = CGAffineTransform(scaleX: 1, y: -1)
        }
        
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        
        // Layout
        
        defaultMinimalHeightConstraint.isActive = false

        // The label is a subview of the background view
        contentView.addSubview(systemMessageBackgroundView)
        systemMessageBackgroundView.addSubview(systemMessageWorkConsumerLabel)
        systemMessageBackgroundView.addSubview(systemMessageWorkConsumerImageView)

        systemMessageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        systemMessageWorkConsumerLabel.translatesAutoresizingMaskIntoConstraints = false
        systemMessageWorkConsumerImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            systemMessageBackgroundView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: ChatViewConfiguration.SystemMessage.defaultTopBottomInset
            ),
            systemMessageBackgroundView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -ChatViewConfiguration.SystemMessage.defaultTopBottomInset
            ),
            systemMessageBackgroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            systemMessageBackgroundView.widthAnchor
                .constraint(lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor),
            
            systemMessageBackgroundView.layoutMarginsGuide.topAnchor.constraint(
                equalTo: systemMessageWorkConsumerLabel.topAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.leadingAnchor.constraint(
                equalTo: systemMessageWorkConsumerImageView.leadingAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.bottomAnchor.constraint(
                equalTo: systemMessageWorkConsumerLabel.bottomAnchor
            ),
            systemMessageBackgroundView.layoutMarginsGuide.trailingAnchor.constraint(
                equalTo: systemMessageWorkConsumerLabel.trailingAnchor
            ),
            systemMessageWorkConsumerImageView.trailingAnchor.constraint(
                equalTo: systemMessageWorkConsumerLabel.leadingAnchor,
                constant: -ChatViewConfiguration.SystemMessage.typeIconLabelSpace
            ),
            systemMessageWorkConsumerImageView.centerYAnchor
                .constraint(equalTo: systemMessageWorkConsumerLabel.centerYAnchor),
        ])
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        guard let systemMessage,
              !systemMessage.willBeDeleted,
              case let .workConsumerInfo(type: workConsumerType) = systemMessage.systemMessageType
        else {
            return
        }
        
        systemMessageWorkConsumerLabel.textColor = .white
        systemMessageWorkConsumerLabel.highlightedTextColor = .white
        systemMessageBackgroundView.backgroundColor = workConsumerType.backgroundColor
    }
    
    private func updateCell(for systemMessage: SystemMessage?) {
        guard case let .workConsumerInfo(type: workConsumerType) = systemMessage?.systemMessageType else {
            return
        }
        
        systemMessageWorkConsumerLabel.text = workConsumerType.localizedMessage
        systemMessageWorkConsumerImageView.image = workConsumerType.symbol
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
