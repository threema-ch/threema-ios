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

import UIKit

final class MessageGroupReactionView: UIView {
    
    /// Message to show group reactions for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message else {
                return
            }
                    
            updateGroupAck(for: message)
        }
    }
        
    // MARK: - Private properties
    
    private lazy var acknowledgedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(acknowledgedImageView)
        view.addSubview(acknowledgedLabel)
        
        NSLayoutConstraint.activate([
            acknowledgedImageView.topAnchor.constraint(equalTo: view.topAnchor),
            acknowledgedImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            acknowledgedImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            acknowledgedLabel.topAnchor.constraint(equalTo: view.topAnchor),
            acknowledgedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            acknowledgedLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            acknowledgedLabel.leadingAnchor.constraint(
                equalTo: acknowledgedImageView.trailingAnchor,
                constant: ChatViewConfiguration.MessageMetadata.defaultLabelGroupReactionSymbolSpace
            ),
        ])
        
        return view
    }()
    
    private lazy var acknowledgedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = message?.groupReactionsThumbsUpImage
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var acknowledgedLabel: UILabel = {
        let label = UILabel()
        label.font = ChatViewConfiguration.MessageMetadata.font
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textColor = Colors.thumbUp
        
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var declinedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(declinedImageView)
        view.addSubview(declinedLabel)
        
        NSLayoutConstraint.activate([
            declinedImageView.topAnchor.constraint(equalTo: view.topAnchor),
            declinedImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            declinedImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            declinedLabel.topAnchor.constraint(equalTo: view.topAnchor),
            declinedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            declinedLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            declinedLabel.leadingAnchor.constraint(
                equalTo: declinedImageView.trailingAnchor,
                constant: ChatViewConfiguration.MessageMetadata.defaultLabelGroupReactionSymbolSpace
            ),
        ])

        return view
    }()
    
    private lazy var declinedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = message?.groupReactionsThumbsDownImage
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var declinedLabel: UILabel = {
        let label = UILabel()
        label.font = ChatViewConfiguration.MessageMetadata.font
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textColor = Colors.thumbDown
        
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var acknowledgedConstraints: [NSLayoutConstraint] = [
        acknowledgedView.topAnchor.constraint(equalTo: topAnchor),
        acknowledgedView.trailingAnchor.constraint(equalTo: trailingAnchor),
        acknowledgedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        acknowledgedView.leadingAnchor.constraint(equalTo: leadingAnchor),
    ]
    
    private lazy var declinedConstraints: [NSLayoutConstraint] = [
        declinedView.topAnchor.constraint(equalTo: topAnchor),
        declinedView.trailingAnchor.constraint(equalTo: trailingAnchor),
        declinedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        declinedView.leadingAnchor.constraint(equalTo: leadingAnchor),
    ]
    
    private lazy var acknowledgedDeclinedConstraints: [NSLayoutConstraint] = [
        acknowledgedView.topAnchor.constraint(equalTo: topAnchor),
        acknowledgedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        acknowledgedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            
        declinedView.topAnchor.constraint(equalTo: topAnchor),
        declinedView.trailingAnchor.constraint(equalTo: trailingAnchor),
        declinedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        declinedView.leadingAnchor.constraint(
            equalTo: acknowledgedView.trailingAnchor,
            constant: ChatViewConfiguration.MessageMetadata.defaultLabelAndSymbolSpace
        ),
    ]

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
        
        addSubview(acknowledgedView)
        addSubview(declinedView)
        updateColors()
    }
    
    // MARK: - Updates
    
    func updateColors() {
        acknowledgedLabel.textColor = Colors.thumbUp
        acknowledgedLabel.highlightedTextColor = Colors.thumbUp
        declinedLabel.textColor = Colors.thumbDown
        declinedLabel.highlightedTextColor = Colors.thumbDown
        
        if let message, !message.willBeDeleted {
            updateGroupAck(for: message)
        }
    }
        
    // MARK: Group ack
    
    private func updateGroupAck(for message: BaseMessage) {
        
        updateAcknowledgedView()
        updateDeclinedView()
        
        switch message.messageGroupReactionState {
        case .none:
            acknowledgedView.isHidden = true
            declinedView.isHidden = true
            NSLayoutConstraint.deactivate(acknowledgedConstraints)
            NSLayoutConstraint.deactivate(declinedConstraints)
            NSLayoutConstraint.deactivate(acknowledgedDeclinedConstraints)
        case .acknowledged:
            acknowledgedView.isHidden = false
            declinedView.isHidden = true
            NSLayoutConstraint.activate(acknowledgedConstraints)
            NSLayoutConstraint.deactivate(declinedConstraints)
            NSLayoutConstraint.deactivate(acknowledgedDeclinedConstraints)
        case .declined:
            acknowledgedView.isHidden = true
            declinedView.isHidden = false
            NSLayoutConstraint.deactivate(acknowledgedConstraints)
            NSLayoutConstraint.activate(declinedConstraints)
            NSLayoutConstraint.deactivate(acknowledgedDeclinedConstraints)
        case .acknowledgedAndDeclined:
            acknowledgedView.isHidden = false
            declinedView.isHidden = false
            NSLayoutConstraint.deactivate(acknowledgedConstraints)
            NSLayoutConstraint.deactivate(declinedConstraints)
            NSLayoutConstraint.activate(acknowledgedDeclinedConstraints)
        }
    }
                        
    private func updateAcknowledgedView() {
        let count = message?.groupReactionsCount(of: .acknowledged) ?? 0
        acknowledgedLabel.text = count > 0 ? String(count) : nil
        acknowledgedImageView.image = message?.groupReactionsThumbsUpImage
    }
    
    private func updateDeclinedView() {
        let count = message?.groupReactionsCount(of: .declined) ?? 0
        declinedLabel.text = count > 0 ? String(count) : nil
        declinedImageView.image = message?.groupReactionsThumbsDownImage
    }
}
