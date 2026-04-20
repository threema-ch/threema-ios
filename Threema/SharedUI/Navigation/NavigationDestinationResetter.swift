final class NavigationDestinationResetter: NSObject, UINavigationControllerDelegate {
    private weak var rootViewController: UIViewController?
    private weak var splitViewController: UISplitViewController?
    private let destinationHolder: (any CurrentDestinationHolderProtocol)?
    
    init(
        rootViewController: UIViewController,
        splitViewController: UISplitViewController?,
        destinationHolder: any CurrentDestinationHolderProtocol
    ) {
        self.rootViewController = rootViewController
        self.splitViewController = splitViewController
        self.destinationHolder = destinationHolder
    }
    
    // MARK: - UINavigationControllerDelegate
    
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        
        if let statusNavigationController = navigationController as? StatusNavigationController {
            statusNavigationController.updateNavigationBarContent()
        }
    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        /// If we navigate back to the rootViewController, we reset the destination
        /// only if the splitViewController is collapsed
        guard navigationController.topViewController == rootViewController,
              splitViewController?.isCollapsed == true else {
            return
        }
        
        destinationHolder?.resetCurrentDestination()
    }
}
