import UIKit

/// Base class for `UITableViewHeaderFooterView` that are implemented in code
open class ThemedCodeTableViewHeaderFooterView: UITableViewHeaderFooterView {
    
    // Normally you don't need to override `init`. Just do you configuration in `configureView()`.
    override public init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        configureView()
        updateColors()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureView() {
        // no-op
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        updateColors()
    }
    
    /// Called whenever the colors of the views should be set to the current theme colors
    open func updateColors() {
        // no-op
    }
}
