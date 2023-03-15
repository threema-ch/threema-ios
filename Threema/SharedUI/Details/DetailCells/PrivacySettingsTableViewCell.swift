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

class PrivacySettingsTableViewCell: ThemedCodeStackTableViewCell {
    
    public enum PrivacySettingType {
        case typingIndicator, readReceipt
    }
    
    // MARK: - Public property

    var contact: ContactEntity?
    
    var action: Details.Action? {
        didSet {
            guard let action = action else {
                return
            }
            
            labelLabel.text = action.title
            
            guard let contact = contact else {
                return
            }
            
            if action.title == BundleUtil.localizedString(forKey: "send_readReceipts") {
                let defaultString = UserSettings.shared().sendReadReceipts ?
                    BundleUtil.localizedString(forKey: "send") : BundleUtil.localizedString(forKey: "dont_send")
                
                switch contact.readReceipt {
                case .send:
                    stateLabel.text = BundleUtil.localizedString(forKey: "send")
                    
                case .doNotSend:
                    stateLabel.text = BundleUtil.localizedString(forKey: "dont_send")
                    
                default:
                    stateLabel.text = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "default_send"),
                        defaultString
                    )
                }
            }
            else {
                let defaultString = UserSettings.shared().sendTypingIndicator ?
                    BundleUtil.localizedString(forKey: "send") : BundleUtil.localizedString(forKey: "dont_send")
               
                switch contact.typingIndicator {
                case .send:
                    stateLabel.text = BundleUtil.localizedString(forKey: "send")
                    
                case .doNotSend:
                    stateLabel.text = BundleUtil.localizedString(forKey: "dont_send")
                    
                default:
                    stateLabel.text = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "default_send"),
                        defaultString
                    )
                }
            }
        }
    }
    
    // MARK: - Private properties
    
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
    
    private lazy var stateLabel: UILabel = {
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
        contentStack.addArrangedSubview(stateLabel)
    }
    
    override func updateColors() {
        super.updateColors()
        
        stateLabel.textColor = Colors.textLight
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
            stateLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension PrivacySettingsTableViewCell: Reusable { }
