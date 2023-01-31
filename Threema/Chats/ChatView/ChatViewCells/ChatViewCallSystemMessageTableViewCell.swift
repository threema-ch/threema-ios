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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

/// Display a call message
final class ChatViewCallSystemMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    static var sizingCell = ChatViewCallSystemMessageTableViewCell()
    
    /// Call message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var callMessageAndNeighbors: (message: SystemMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            updateCell(for: callMessageAndNeighbors?.message)
            
            super.setMessage(to: callMessageAndNeighbors?.message, with: callMessageAndNeighbors?.neighbors)
        }
    }
    
    // MARK: - Views
    
    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.Text.symbolConfiguration
        imageView.accessibilityElementsHidden = true
        return imageView
    }()
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: nil)
    private lazy var metaDataLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.numberOfLines = 0
        label.font = ChatViewConfiguration.MessageMetadata.font
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var stateAndDateView = MessageDateAndStateView()
    
    /// Stack view containing metaDataLabel and the dateAndStateView
    private lazy var metaDataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [metaDataLabel, stateAndDateView])
        stackView.alignment = .firstBaseline
        stackView.distribution = .fill
        
        // We switch from horizontal to vertical if accessibility fonts are enabled
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
        }
        else {
            stackView.spacing = ChatViewConfiguration.MessageMetadata.minimalInBetweenSpace
            stackView.axis = .horizontal
        }
                
        return stackView
    }()
    
    private lazy var iconMessageContentView = IconMessageContentView(iconView: iconView, arrangedSubviews: [
        messageTextView,
        metaDataStackView,
    ]) {
        [weak self] in
            guard let strongSelf = self else {
                return
            }
        
            strongSelf.chatViewTableViewCellDelegate?.didTap(
                message: strongSelf.callMessageAndNeighbors?.message,
                in: strongSelf
            )
    }
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
         
        messageTextView.isUserInteractionEnabled = false
        super.addContent(rootView: iconMessageContentView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        if case let .callMessage(type: call) = callMessageAndNeighbors?.message.systemMessageType {
            iconView.image = call.symbol
        }
        messageTextView.updateColors()
        Colors.setTextColor(Colors.textLight, label: metaDataLabel)
        stateAndDateView.updateColors()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        iconMessageContentView.isUserInteractionEnabled = !editing
    }
    
    private func updateCell(for callMessage: SystemMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        guard case let .callMessage(type: call) = callMessage?.systemMessageType else {
            return
        }

        iconView.image = call.symbol
        messageTextView.text = call.localizedMessage
        stateAndDateView.message = callMessage
        
        // We remove the duration label if there is no call time, OR statements are not possible with if case, so we use else if
        if case let .endedIncomingSuccessful(duration: timeString) = call {
            metaDataLabel.attributedText = duration(callTime: timeString)
            metaDataStackView.insertArrangedSubview(metaDataLabel, at: 0)
        }
        else if case let .endedOutgoingSuccessful(duration: timeString) = call {
            metaDataLabel.attributedText = duration(callTime: timeString)
            metaDataStackView.insertArrangedSubview(metaDataLabel, at: 0)
        }
        else {
            metaDataStackView.removeArrangedSubview(metaDataLabel)
            metaDataLabel.removeFromSuperview()
        }
        
        // Fixes a bug where the call icon could be miss-aligned in iOS 13
        if #available(iOS 14.0, *) {
            // Do nothing
        }
        else {
            iconMessageContentView.layoutIfNeeded()
        }
        
        updateAccessibility()
    }
    
    /// Get NSAttributedString of style "􀐱 xx:xx" containing the duration of the call message
    /// - Parameter callTime: Duration of message
    /// - Returns: Attributed string
    private func duration(callTime: String?) -> NSMutableAttributedString? {
        
        guard let callTime = callTime else {
            return nil
        }
       
        let icon = UIImage(
            systemName: "timer",
            withConfiguration: ChatViewConfiguration.MessageMetadata.symbolConfiguration
        )?
            .withTintColor(Colors.textLight)
        
        // Combine String
        let duration = NSMutableAttributedString(string: callTime)
        
        if let icon = icon {
            let timerImage = NSTextAttachment()
            timerImage.image = icon
            let timerString = NSAttributedString(attachment: timerImage)
            let spaceString = NSAttributedString(string: " ")
            duration.insert(spaceString, at: 0)
            duration.insert(timerString, at: 0)
        }
        
        return duration
    }
    
    // MARK: - Accessibility
    
    private func updateAccessibility() {
        guard let callTime = callMessageAndNeighbors?.message.callTime() else {
            return
        }
    
        metaDataLabel.accessibilityLabel = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "call_duration"),
            callTime
        )
    }
}

// MARK: - Reusable

extension ChatViewCallSystemMessageTableViewCell: Reusable { }

// MARK: - ContextMenuAction

extension ChatViewCallSystemMessageTableViewCell: ContextMenuAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {

        guard let message = callMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewContextMenuActionProvider
            
        let editAction = Provider.editAction {
            self.chatViewTableViewCellDelegate?.startMultiselect()
        }
        
        let deleteAction = Provider.deleteAction(message: message)
        
        // Build menu
        let menu = UIMenu(children: [editAction, deleteAction])
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}
