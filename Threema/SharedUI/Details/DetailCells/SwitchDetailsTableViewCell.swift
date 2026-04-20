import UIKit

final class SwitchDetailsTableViewCell: ThemedCodeStackTableViewCell {
    
    // MARK: Public property
    
    var action: Details.BooleanAction? {
        didSet {
            guard let action else {
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
            switchControl.onTintColor = .systemRed
        }
        else {
            switchControl.onTintColor = .tintColor
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
