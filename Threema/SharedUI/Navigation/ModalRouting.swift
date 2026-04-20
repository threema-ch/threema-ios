protocol ModalRouterProtocol: AnyObject {
    var rootViewController: UIViewController { get }
    
    func present(
        _ viewController: UIViewController,
        animated: Bool,
        style: UIModalPresentationStyle,
        transition: UIModalTransitionStyle,
        completion: (() -> Void)?
    )
}

extension ModalRouterProtocol {
    func present(
        _ viewController: UIViewController,
        animated: Bool = true,
        style: UIModalPresentationStyle = .automatic,
        transition: UIModalTransitionStyle = .coverVertical,
        completion: (() -> Void)? = nil
    ) {
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = style
        navigationController.modalTransitionStyle = transition
        rootViewController.present(
            navigationController,
            animated: animated,
            completion: completion
        )
    }
}

final class ModalRouter: ModalRouterProtocol {
    let rootViewController: UIViewController
    
    init(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }
}
