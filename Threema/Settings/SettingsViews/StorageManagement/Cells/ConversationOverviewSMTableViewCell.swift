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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

class ConversationOverviewSMTableViewCell: ThemedCodeStackTableViewCell {

    private var conversation: Conversation?
     
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView()
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fill
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
        
        return stackView
    }()
    
    private lazy var countStack: UIStackView = {
        let stackView = UIStackView()
        
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .trailing
        stackView.distribution = .fill
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
        
        return stackView
    }()
                    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(image: BundleUtil.imageNamed("Unknown"))
        
        imageView.contentMode = .scaleAspectFit
        
        imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 40).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        imageView.accessibilityIgnoresInvertColors = true
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            imageView.isHidden = true
        }
        
        return imageView
    }()
    
    private lazy var threemaTypeIcon: UIImageView = {
        let imageView = OtherThreemaTypeImageView()
        
        // We shouldn't accidentally show it
        imageView.isHidden = true
        
        // Aspect ratio: 1:1
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
          
    private lazy var conversationLabel: UILabel = {
        let label = UILabel()
        
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.textAlignment = .left
        
        label.numberOfLines = 0
            
        return label
    }()
    
    private lazy var messagesLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        label.text = "messages".localized
        
        label.textColor = Colors.textLight
        
        return label
    }()
    
    private lazy var storageLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        label.text = "files".localized
                
        return label
    }()
        
    override func configureCell() {
        super.configureCell()
                
        selectionStyle = .default
        accessoryType = .disclosureIndicator
        
        threemaTypeIcon.translatesAutoresizingMaskIntoConstraints = false
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Approximation for a similar size to verification level image
            // Setting the size to the size of the verification level image view didn't work.
            threemaTypeIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        }
        else {
            // The avatar view combined with the type icon is only shown for non accessibility content
            // sizes, thus we only should set it as a subview with constraints then
            avatarImageView.addSubview(threemaTypeIcon)
            NSLayoutConstraint.activate([
                // 0.35x of the avatar image size
                threemaTypeIcon.widthAnchor.constraint(equalTo: avatarImageView.widthAnchor, multiplier: 0.35),
                
                // In the bottom left of the avatar view (in ltr)
                threemaTypeIcon.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
                threemaTypeIcon.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            ])
        }
        
        containerStack.addArrangedSubview(avatarImageView)
        containerStack.addArrangedSubview(conversationLabel)
        contentStack.addArrangedSubview(containerStack)
        countStack.addArrangedSubview(messagesLabel)
        countStack.addArrangedSubview(storageLabel)
        contentStack.addArrangedSubview(countStack)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        conversation = nil
    }
    
    override func updateColors() {
        super.updateColors()
        
        messagesLabel.textColor = Colors.textLight
        storageLabel.textColor = Colors.textLight
    }
    
    // MARK: - Private Methods
    
    public func setupConversation(_ conversation: Conversation, businessInjector: BusinessInjectorProtocol) {
        self.conversation = conversation
        
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                let messageFetcher = MessageFetcher(for: conversation, with: businessInjector.entityManager)
                self.messagesLabel.text = "\(messageFetcher.count()) \("messages".localized)"
                self.storageLabel.text = "\(messageFetcher.mediaCount()) \("files".localized)"
            }
            
            AvatarMaker.shared()
                .avatar(for: conversation, size: 40, masked: true) { avatarImage, objectID in
                    guard let avatarImage,
                          let objectID else {
                        // Show placeholder
                        self.avatarImageView.image = AvatarMaker.shared().unknownPersonImage()
                        return
                    }
                    
                    if objectID == conversation.objectID {
                        DispatchQueue.main.async {
                            self.avatarImageView.image = avatarImage
                        }
                    }
                }
        }
        
        if conversation.isGroup() {
            conversationLabel.text = conversation.groupName
            threemaTypeIcon.isHidden = true
        }
        else {
            conversationLabel.text = conversation.displayName
            threemaTypeIcon.isHidden = ThreemaUtility.shouldHideOtherTypeIcon(for: conversation.contact)
        }
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            conversationLabel.accessibilityLabel
        }
        set { }
    }
    
    override public var accessibilityValue: String? {
        get {
            messagesLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension ConversationOverviewSMTableViewCell: Reusable { }
