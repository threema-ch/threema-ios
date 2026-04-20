import CocoaLumberjackSwift
import Contacts
import ThreemaMacros
import UIKit

final class LinkedContactDetailsTableViewCell: ThemedCodeStackTableViewCell {
    
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
        label.textColor = .label
        
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
        contentStack.addArrangedSubview(contactNameLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        linkedContactManagerObserverToken?.cancel()
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
