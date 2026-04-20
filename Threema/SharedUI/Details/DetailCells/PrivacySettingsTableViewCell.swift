import ThreemaMacros
import UIKit

final class PrivacySettingsTableViewCell: ThemedCodeStackTableViewCell {
    
    public enum PrivacySettingType {
        case typingIndicator, readReceipt
    }
    
    // MARK: - Public property

    var contact: ContactEntity?
    
    var action: Details.Action? {
        didSet {
            guard let action else {
                return
            }
            
            labelLabel.text = action.title
            
            guard let contact else {
                return
            }
            
            if action.title == #localize("send_readReceipts") {
                let defaultString = UserSettings.shared().sendReadReceipts ?
                    #localize("send") : #localize("dont_send")
                
                switch contact.readReceipt {
                case .send:
                    stateLabel.text = #localize("send")
                    
                case .doNotSend:
                    stateLabel.text = #localize("dont_send")
                    
                default:
                    stateLabel.text = String.localizedStringWithFormat(
                        #localize("default_send"),
                        defaultString
                    )
                }
            }
            else {
                let defaultString = UserSettings.shared().sendTypingIndicator ?
                    #localize("send") : #localize("dont_send")
               
                switch contact.typingIndicator {
                case .send:
                    stateLabel.text = #localize("send")
                    
                case .doNotSend:
                    stateLabel.text = #localize("dont_send")
                    
                default:
                    stateLabel.text = String.localizedStringWithFormat(
                        #localize("default_send"),
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
        label.textColor = .label
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.numberOfLines = 0
        
        return label
    }()
    
    private lazy var stateLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        
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
