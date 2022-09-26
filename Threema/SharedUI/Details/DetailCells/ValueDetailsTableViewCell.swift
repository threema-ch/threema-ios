//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class ValueDetailsTableViewCell: ThemedCodeStackTableViewCell {

    var label: String? {
        didSet {
            labelLabel.text = label
        }
    }
    
    var value: String? {
        didSet {
            valueLabel.text = value
        }
    }
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var valueLabel: CopyLabel = {
        let label = CopyLabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentStack.addArrangedSubview(labelLabel)
        contentStack.addArrangedSubview(valueLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        label = nil
        value = nil
    }
    
    override func updateColors() {
        super.updateColors()
        
        valueLabel.textColor = Colors.textLight
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
            valueLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension ValueDetailsTableViewCell: Reusable { }
