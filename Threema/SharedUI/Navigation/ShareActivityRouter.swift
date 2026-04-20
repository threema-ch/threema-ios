import UIKit

protocol ShareActivityRouterProtocol: AnyObject {
    var rootViewController: UIViewController { get }
    
    func present(items: [Any], sourceView: UIView?)
}

extension ShareActivityRouterProtocol {
    /// Presents a share activity with the given items from the given source view
    /// - Parameters:
    ///   - items: Items to be forwarded to `UIActivityViewController`
    ///   - sourceView: `UIView` acting as popover source
    func present(items: [Any], sourceView: UIView?) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = sourceView
        rootViewController.present(activityViewController, animated: true)
    }
}

final class ShareActivityRouter: ShareActivityRouterProtocol {
    let rootViewController: UIViewController
    
    init(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }
}
