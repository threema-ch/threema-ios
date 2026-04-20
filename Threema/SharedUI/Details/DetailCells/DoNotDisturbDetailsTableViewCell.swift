import UIKit

final class DoNotDisturbDetailsTableViewCell: ThemedCodeStackTableViewCell {

    enum PushSettingType {
        case contact(_: ContactEntity)
        case group(_: Group)
    }
    
    // MARK: - Public property
    
    var action: Details.Action? {
        didSet {
            guard let action else {
                return
            }
            
            labelLabel.text = action.title
        }
    }
    
    var type: PushSettingType? {
        didSet {
            guard let type else {
                return
            }
            
            switch type {
            case let .contact(contact):
                pushSetting = BusinessInjector.ui.pushSettingManager
                    .find(forContact: contact.threemaIdentity)
            case let .group(group):
                pushSetting = group.pushSetting
            }
        }
    }
    
    private var pushSetting: PushSetting? {
        didSet {
            guard let pushSetting else {
                return
            }
            
            stateLabel.text = pushSetting.localizedDescription
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

extension DoNotDisturbDetailsTableViewCell: Reusable { }
