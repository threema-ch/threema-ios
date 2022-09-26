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

import Foundation

/// Display file messages
final class ChatViewFileMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewFileMessageTableViewCell()
    
    /// File message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var fileMessage: FileMessage? {
        didSet {
            super.setMessage(to: fileMessage)
            updateCell(for: fileMessage)
        }
    }
    
    // MARK: - Views & constraints
    
    private lazy var fileButton = MessageFileButton { _ in
        // TODO: (IOS-2590) Implement
        print("File button pressed")
    }
    
    // These are only shown if there is a caption...
    private lazy var captionTextLabel = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    private lazy var captionStack: DefaultMessageContentStackView = {
        let stack = DefaultMessageContentStackView(arrangedSubviews: [
            fileButton,
            captionTextLabel,
            messageDateAndStateView,
        ])
        
        stack.setCustomSpacing(ChatViewConfiguration.File.fileButtonAndCaptionSpace, after: fileButton)
        
        return stack
    }()
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        super.addContent(rootView: captionStack)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        captionTextLabel.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for fileMessage: FileMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        fileButton.fileMessage = fileMessage
        
        if !(fileMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = fileMessage?.caption
            messageDateAndStateView.message = fileMessage
            
            captionTextLabel.isHidden = false
            messageDateAndStateView.isHidden = false
        }
        else {
            captionTextLabel.isHidden = true
            messageDateAndStateView.isHidden = true
        }
    }
}

// MARK: - Reusable

extension ChatViewFileMessageTableViewCell: Reusable { }

// MARK: - MessageTextViewDelegate

extension ChatViewFileMessageTableViewCell: MessageTextViewDelegate { }
