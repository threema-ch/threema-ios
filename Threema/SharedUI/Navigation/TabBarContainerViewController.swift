import UIKit

/// A plain `UIViewController` wrapper around `ThreemaTabBarController`.
///
/// The column-based `UISplitViewController` API prohibits assigning a
/// `UITabBarController` directly to the `.primary` column. This container
/// works around that restriction by embedding the tab bar controller as a
/// child view controller.
final class TabBarContainerViewController: UIViewController {

    let embeddedTabBarController: ThreemaTabBarController
    
    private var handedDownBottomInset: CGFloat = 0

    init(embeddedTabBarController: ThreemaTabBarController) {
        self.embeddedTabBarController = embeddedTabBarController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(embeddedTabBarController)
        view.addSubview(embeddedTabBarController.view)
        embeddedTabBarController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            embeddedTabBarController.view.topAnchor.constraint(equalTo: view.topAnchor),
            embeddedTabBarController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            embeddedTabBarController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            embeddedTabBarController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        embeddedTabBarController.didMove(toParent: self)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        handDownMissingBottomInset()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        handDownMissingBottomInset()
    }

    /// In landscape UIKit gives the embedded tab bar controller no bottom safe area, so the tab bar is 32pt
    /// instead of 53pt and lands under the home indicator. Portrait propagates fine, so only top up what is
    /// missing. Not needed on iOS 26+.
    private func handDownMissingBottomInset() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let propagated = embeddedTabBarController.view.safeAreaInsets.bottom - handedDownBottomInset
        let missing = max(0, view.safeAreaInsets.bottom - propagated)

        guard missing != handedDownBottomInset else {
            return
        }

        handedDownBottomInset = missing
        embeddedTabBarController.additionalSafeAreaInsets.bottom = missing
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        // The column-based split VC auto-wraps this container in a
        // UINavigationController. Hide its navigation bar so it doesn't
        // add extra space above the tab bar's own navigation bars.
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}
