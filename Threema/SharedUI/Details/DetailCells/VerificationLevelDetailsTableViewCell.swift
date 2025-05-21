//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaMacros
import UIKit

final class VerificationLevelDetailsTableViewCell: ThemedCodeStackTableViewCell {
    
    private var contactObserver: NSKeyValueObservation?

    var contact: ContactEntity? {
        didSet {
            contactObserver?.invalidate()

            contactObserver = contact?
                .observe(\.contactVerificationLevel, options: .initial) { [weak self] contact, _ in
                    DispatchQueue.main.async {
                        guard let strongSelf = self else {
                            return
                        }
                    
                        let businessContact = Contact(contactEntity: contact)
                        if strongSelf.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                            // When all text is big, we make the image also bigger
                            strongSelf.verificationLevelImageView.image = businessContact.verificationLevelImageBig
                        }
                        else {
                            strongSelf.verificationLevelImageView.image = businessContact.verificationLevelImage
                        }
                    }
                }
        }
    }
    
    // MARK: Subviews
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.text = #localize("verification_level_title")
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var verificationLevelImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .right
        
        return imageView
    }()
    
    // MARK: Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        accessoryType = .disclosureIndicator
        
        contentStack.addArrangedSubview(labelLabel)
        contentStack.addArrangedSubview(verificationLevelImageView)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        contactObserver?.invalidate()
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            labelLabel.accessibilityLabel
        }
        set { }
    }
    
    override public var accessibilityValue: String? {
        get {
            guard let contact else {
                return nil
            }
            let businessContact = Contact(contactEntity: contact)
            return businessContact.verificationLevelAccessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension VerificationLevelDetailsTableViewCell: Reusable { }
