import UIKit

open class ThemedViewController: UIViewController {
    
    // MARK: - Lifecycle
    
    override open func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateColors()
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateColors()
        }
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateColors()
    }
    
    // MARK: - Public methods
    
    /// Called whenever the colors of the views should be set to the current theme colors
    open func updateColors() {
        view.backgroundColor = Colors.backgroundViewController
    }
}
