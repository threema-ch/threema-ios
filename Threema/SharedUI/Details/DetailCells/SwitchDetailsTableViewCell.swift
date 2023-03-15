//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

class SwitchDetailsTableViewCell: ThemedCodeStackTableViewCell {
    
    // MARK: Public property
    
    var action: Details.BooleanAction? {
        didSet {
            guard let action = action else {
                return
            }
            
            labelLabel.text = action.title
            labelLabel.isEnabled = !action.disabled
            switchControl.isOn = action.currentBool()
            switchControl.isEnabled = !action.disabled
            
            updateColors()
        }
    }
    
    // MARK: Subviews
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
        
    private lazy var switchControl: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        return toggle
    }()
    
    // MARK: Lifecycle
    
    override func prepareForReuse() {
        action = nil
    }
    
    // MARK: Configuration
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        accessoryView = switchControl
        
        contentStack.addArrangedSubview(labelLabel)
    }
    
    // MARK: Update
    
    override func updateColors() {
        super.updateColors()
        
        if let isDestructive = action?.destructive, isDestructive {
            switchControl.onTintColor = Colors.red
        }
        else {
            switchControl.onTintColor = .primary
        }
    }
    
    // MARK: Action
    
    @objc private func switchChanged() {
        action?.run(switchControl.isOn)
    }
    
    // MARK: Accessibility
    
    override var accessibilityLabel: String? {
        get {
            labelLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension SwitchDetailsTableViewCell: Reusable { }
