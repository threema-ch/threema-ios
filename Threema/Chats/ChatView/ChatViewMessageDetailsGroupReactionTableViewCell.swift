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

// Show a group reaction in message details
final class ChatViewMessageDetailsGroupReactionTableViewCell: ThemedCodeStackTableViewCell {
    
    var groupDeliveryReceipt: GroupDeliveryReceipt? {
        didSet {
            if groupDeliveryReceipt?.identity == MyIdentityStore.shared().identity {
                nameLabel.text = BundleUtil.localizedString(forKey: "Me")
            }
            else {
                if let contact = entityManager.entityFetcher.contact(for: groupDeliveryReceipt?.identity) {
                    nameLabel.text = contact.displayName
                }
                else {
                    nameLabel.text = groupDeliveryReceipt?.identity
                }
            }

            reactionSymbolImageView.image = groupDeliveryReceipt?.icon()
        }
    }
    
    private let entityManager = BusinessInjector().entityManager
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var reactionSymbolImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        
        return imageView
    }()
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(reactionSymbolImageView)
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            nameLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension ChatViewMessageDetailsGroupReactionTableViewCell: Reusable { }
