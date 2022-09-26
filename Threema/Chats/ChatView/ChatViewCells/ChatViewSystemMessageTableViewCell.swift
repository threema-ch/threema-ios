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

import ThreemaFramework
import UIKit

/// Display a system message
final class ChatViewSystemMessageTableViewCell: ThemedCodeTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewSystemMessageTableViewCell()
    
    /// System message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views.
    var systemMessage: SystemMessage? {
        didSet {
            updateCell(for: systemMessage)
        }
    }
    
    // MARK: - Views

    private lazy var systemMessageTextLabel = SystemMessageTextLabel()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        contentView.addSubview(systemMessageTextLabel)
        systemMessageTextLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            systemMessageTextLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            systemMessageTextLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
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
        systemMessage?.objectID
    }

    var messageDate: Date? {
        systemMessage?.sectionDate
    }
}
