import UIKit

/// Base class for `UITableViewCells` that are implemented in code
open class ThemedCodeTableViewCell: UITableViewCell {
    
    /// Constraint for default minimal cell height
    ///
    /// You should normally leave this as-is.
    public lazy var defaultMinimalHeightConstraint: NSLayoutConstraint = {
        let constant =
            if #available(iOS 26.0, *) {
                52.0
            }
            else {
                44.0
            }
        
        return contentView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: constant
        )
    }()
    
    private var themeUsedInLastColorsUpdate = Colors.theme
    
    // Normally you don't need to override `init`. Just do you configuration in `configureCell()`.
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        configureCell()
        updateColors()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureCell() {
        defaultMinimalHeightConstraint.isActive = true
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        // Only update colors if theme changed
        if themeUsedInLastColorsUpdate != Colors.theme {
            updateColors()
        }
    }
    
    /// Called whenever the colors of the views should be set to the current theme colors
    @objc open func updateColors() {
        themeUsedInLastColorsUpdate = Colors.theme
    }
}
