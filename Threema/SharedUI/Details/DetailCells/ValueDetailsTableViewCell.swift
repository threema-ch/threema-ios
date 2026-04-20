import UIKit

final class ValueDetailsTableViewCell: ThemedCodeStackTableViewCell {

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
        label.textColor = .label
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var valueLabel: CopyLabel = {
        let label = CopyLabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
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
        
        NSLayoutConstraint.activate([
            labelLabel.widthAnchor.constraint(lessThanOrEqualTo: contentStack.widthAnchor, multiplier: 0.5),
            labelLabel.widthAnchor.constraint(greaterThanOrEqualTo: contentStack.widthAnchor, multiplier: 0.4),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        label = nil
        value = nil
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
