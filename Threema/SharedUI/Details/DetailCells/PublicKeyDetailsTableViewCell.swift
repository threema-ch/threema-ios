import ThreemaMacros
import UIKit

final class PublicKeyDetailsTableViewCell: ThemedCodeStackTableViewCell {
        
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        label.text = #localize("public_key")
        
        return label
    }()
        
    override func configureCell() {
        super.configureCell()
                
        accessoryType = .disclosureIndicator
        
        contentStack.addArrangedSubview(labelLabel)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            labelLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension PublicKeyDetailsTableViewCell: Reusable { }
