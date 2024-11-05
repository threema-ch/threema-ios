//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import Contacts
import ThreemaMacros
import UIKit

class LinkedContactDetailsTableViewCell: ThemedCodeStackTableViewCell {
    
    var linkedContactManager: LinkedContactManager? {
        didSet {
            linkedContactManagerObserverToken?.cancel()
            
            // Observe changes of linked contact
            linkedContactManagerObserverToken = linkedContactManager?.observe(with: { [weak self] manager in
                self?.labelLabel.text = manager.linkedContactTitle
                self?.contactNameLabel.text = manager.linkedContactDescription
            })
        }
    }
    
    // MARK: - Private properties
    
    private var linkedContactManagerObserverToken: LinkedContactManager.ObservationToken?
        
    // MARK: Subviews
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        // Needed to get correct cell height
        label.text = #localize("linked_contact")
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var contactNameLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()

    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        accessoryType = .disclosureIndicator
        
        contentStack.addArrangedSubview(labelLabel)
        contentStack.addArrangedSubview(contactNameLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        linkedContactManagerObserverToken?.cancel()
    }
    
    override func updateColors() {
        super.updateColors()
        
        contactNameLabel.textColor = Colors.textLight
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
            contactNameLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension LinkedContactDetailsTableViewCell: Reusable { }
