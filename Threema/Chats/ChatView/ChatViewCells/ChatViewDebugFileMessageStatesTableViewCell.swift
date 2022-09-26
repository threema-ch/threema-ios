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

/// Debug display file message states
final class ChatViewDebugFileMessageStatesTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewDebugFileMessageStatesTableViewCell()
    
    /// Text message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var fileMessageEntity: FileMessageEntity? {
        didSet {
            super.setMessage(to: fileMessageEntity)
            updateCell(for: fileMessageEntity)
        }
    }
    
    // MARK: - Views
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var thumbnailStateLabel = UILabel()
    private lazy var dataStateLabel = UILabel()
    private lazy var blobDisplayStateLabel = UILabel()
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        messageTextView,
        thumbnailStateLabel,
        dataStateLabel,
        blobDisplayStateLabel,
        messageDateAndStateView,
    ])

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        super.addContent(rootView: contentStack)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        messageTextView.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for fileMessageEntity: FileMessageEntity?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        // TODO: (IOS-2390) Replace by correct name label implementation
        if let fileMessageEntity = fileMessageEntity,
           fileMessageEntity.conversation.isGroup(),
           !fileMessageEntity.isOwnMessage {
            messageTextView.text = "\(fileMessageEntity.quotedSender): \(fileMessageEntity.logText() ?? "")"
        }
        else {
            messageTextView.text = fileMessageEntity?.logText()
        }

        thumbnailStateLabel.text = "TN: \(fileMessageEntity?.thumbnailState.description ?? "")"
        dataStateLabel.text = "D: \(fileMessageEntity?.dataState.description ?? "")"
        blobDisplayStateLabel.text = "BDL: \(fileMessageEntity?.blobDisplayState.description ?? "")"
        messageDateAndStateView.message = fileMessageEntity
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewDebugFileMessageStatesTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
}

// MARK: - Reusable

extension ChatViewDebugFileMessageStatesTableViewCell: Reusable { }
