import ThreemaFramework
import ThreemaMacros
import UIKit

final class WallpaperTableViewCell: ThemedCodeStackTableViewCell {
    
    // MARK: Public Properties
    
    var action: Details.Action? {
        didSet {
            guard let action else {
                return
            }
            titleLabel.text = action.title
            stateLabel.text = #localize("settings_chat_wallpaper_default")
        }
    }
    
    var isDefault: Bool? {
        didSet {
            guard let isDefault else {
                return
            }
            if isDefault {
                stateLabel.text = #localize("settings_chat_wallpaper_default")
            }
            else {
                stateLabel.text = #localize("settings_chat_wallpaper_custom")
            }
        }
    }
        
    // MARK: Private Properties
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label
        
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
        
    override func configureCell() {
        super.configureCell()
                
        accessoryType = .disclosureIndicator
        
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(stateLabel)
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            titleLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension WallpaperTableViewCell: Reusable { }
