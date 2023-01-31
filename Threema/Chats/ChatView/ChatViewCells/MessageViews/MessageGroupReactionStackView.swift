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

import UIKit

final class MessageGroupReactionStackView: UIStackView {
    
    /// Message to show group reactions for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message = message else {
                return
            }
                    
            updateGroupAck(for: message)
        }
    }
        
    // MARK: - Private properties
            
    private lazy var groupReactionAcknowledgedStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            groupReactionAcknowledgedImageView,
            groupReactionAcknowledgedLabel,
        ])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = ChatViewConfiguration.MessageMetadata.defaultLabelGroupReactionSymbolSpace
        return stackView
    }()
    
    private lazy var groupReactionAcknowledgedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = message?.groupReactionsThumbsUpImage
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        return imageView
    }()
    
    private lazy var groupReactionAcknowledgedLabel: UILabel = {
        let label = UILabel()
        label.font = ChatViewConfiguration.MessageMetadata.font
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var groupReactionDeclinedStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [groupReactionDeclinedImageView, groupReactionDeclinedLabel])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = ChatViewConfiguration.MessageMetadata.defaultLabelGroupReactionSymbolSpace
        return stackView
    }()
    
    private lazy var groupReactionDeclinedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = message?.groupReactionsThumbsDownImage
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        return imageView
    }()
    
    private lazy var groupReactionDeclinedLabel: UILabel = {
        let label = UILabel()
        label.font = ChatViewConfiguration.MessageMetadata.font
        label.textColor = Colors.thumbDown
        label.numberOfLines = 1
        return label
    }()

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        updateColors()
    }
        
    convenience init() {
        self.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureLayout() {
        axis = .horizontal
        distribution = .equalSpacing
        alignment = .center
        spacing = ChatViewConfiguration.MessageMetadata.defaultLabelAndSymbolSpace
        
        addArrangedSubview(groupReactionAcknowledgedStackView)
        addArrangedSubview(groupReactionDeclinedStackView)
    }
    
    // MARK: - Updates
    
    func updateColors() {
        Colors.setTextColor(Colors.thumbUp, label: groupReactionAcknowledgedLabel)
        Colors.setTextColor(Colors.thumbDown, label: groupReactionDeclinedLabel)
        
        if let message = message {
            updateGroupAck(for: message)
        }
    }
        
    // MARK: Group ack
    
    private func updateGroupAck(for message: BaseMessage) {
        switch message.messageGroupReactionState {
        case .none:
            groupReactionAcknowledgedStackView.isHidden = true
            groupReactionDeclinedStackView.isHidden = true
        case .acknowledged:
            updateAcknowledgedStackView()
            groupReactionAcknowledgedStackView.isHidden = false
            groupReactionDeclinedStackView.isHidden = true
        case .declined:
            updateDeclinedStackView()
            groupReactionAcknowledgedStackView.isHidden = true
            groupReactionDeclinedStackView.isHidden = false
        case .acknowledgedAndDeclined:
            updateAcknowledgedStackView()
            updateDeclinedStackView()
            groupReactionAcknowledgedStackView.isHidden = false
            groupReactionDeclinedStackView.isHidden = false
        }
    }
                        
    private func updateAcknowledgedStackView() {
        let count = message?.groupReactionsCount(of: .acknowledged) ?? 0
        groupReactionAcknowledgedLabel.text = count > 0 ? String(count) : nil
        groupReactionAcknowledgedImageView.image = message?.groupReactionsThumbsUpImage
    }
    
    private func updateDeclinedStackView() {
        let count = message?.groupReactionsCount(of: .declined) ?? 0
        groupReactionDeclinedLabel.text = count > 0 ? String(count) : nil
        groupReactionDeclinedImageView.image = message?.groupReactionsThumbsDownImage
    }
}
