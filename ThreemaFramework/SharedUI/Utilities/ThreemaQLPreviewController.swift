import Foundation
import QuickLook

private final class DisableShareUINavigationItem: UINavigationItem {
    override func setRightBarButtonItems(_ items: [UIBarButtonItem]?, animated: Bool) {
        // forbidden to add anything to right
    }

    // Block the title menu (dropdown next to the title), it offers share and export actions

    override var style: UINavigationItem.ItemStyle {
        get { super.style }
        set { super.style = .navigator }
    }

    override var titleMenuProvider: (([UIMenuElement]) -> UIMenu?)? {
        get { super.titleMenuProvider }
        set { super.titleMenuProvider = nil }
    }

    override var documentProperties: UIDocumentProperties? {
        get { super.documentProperties }
        set { super.documentProperties = nil }
    }

    /// Sets our own right bar button items (e.g. close button), bypassing the block above
    func setAllowedRightBarButtonItems(_ items: [UIBarButtonItem]?) {
        super.setRightBarButtonItems(items, animated: false)
    }
}

public final class ThreemaQLPreviewController: QLPreviewController {
    
    private lazy var disableShareNavigationItem = { [self] in
        let navItem = DisableShareUINavigationItem(title: "")
        return navItem
    }()
    
    /// Returns a share-disabled navigation item when sharing is restricted by MDM,
    /// otherwise returns the default QuickLook navigation item.
    override public var navigationItem: UINavigationItem {
        if disableShareButton {
            return disableShareNavigationItem
        }
        else {
            var navItem: UINavigationItem?
            if Thread.isMainThread {
                return super.navigationItem
            }
            else {
                DispatchQueue.main.sync {
                    navItem = super.navigationItem
                }
                return navItem ?? disableShareNavigationItem
            }
        }
    }
        
    var observations: [NSKeyValueObservation] = []
    
    /// Registered only once, as `viewWillAppear` runs on every appearance (e.g. after a call screen was dismissed)
    private var toolbarObservation: NSKeyValueObservation?

    /// Observations for the child view controller QuickLook currently shows (e.g. zip file browser)
    private var childObservations: [NSKeyValueObservation] = []

    var mdmSetup = MDMSetup()

    var disableShareButton = false
    
    /// Called by our close button (see `showsOwnNavigationItemContent`). If `nil`, the controller dismisses itself.
    public var onClose: (() -> Void)?

    private lazy var disableShareCloseButton = UIBarButtonItem.closeButton(
        target: self,
        selector: #selector(closeButtonTapped)
    )

    /// Since iOS 27 QuickLook leaves the share-disabled navigation item empty, without a way to close the preview.
    /// Thus we add the title and a close button ourselves.
    private var showsOwnNavigationItemContent: Bool {
        if #available(iOS 27.0, *) {
            return disableShareButton
        }
        return false
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        disableShareButton = mdmSetup?.disableShareMedia() ?? false
        
        if disableShareButton {
            navigationItem.setRightBarButton(UIBarButtonItem(), animated: false)
        }

        if showsOwnNavigationItemContent {
            // Keeps the title in sync when the user changes to a different preview item
            observations.append(
                observe(\.currentPreviewItemIndex) { [weak self] _, _ in
                    self?.updateDisableShareNavigationItem()
                }
            )
        }
    }
    
    /// Hides the navigation toolbar and registers this controller as the navigation
    /// controller delegate to intercept child view controllers pushed by QuickLook.
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        removeToolbarItems()

        if disableShareButton {
            navigationController?.delegate = self
        }

        updateDisableShareNavigationItem()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // QuickLook may set its title only once the preview item is loaded
        updateDisableShareNavigationItem()
    }

    private func updateDisableShareNavigationItem() {
        guard showsOwnNavigationItemContent else {
            return
        }

        disableShareNavigationItem.title = currentItemTitle

        if disableShareNavigationItem.rightBarButtonItems?.first !== disableShareCloseButton {
            disableShareNavigationItem.setAllowedRightBarButtonItems([disableShareCloseButton])
        }
    }

    /// QuickLook's own title, otherwise the title or file name of the current item
    private var currentItemTitle: String? {
        if let quickLookTitle = super.navigationItem.title, !quickLookTitle.isEmpty {
            return quickLookTitle
        }
        guard let item = currentPreviewItem else {
            return nil
        }
        if let title = item.previewItemTitle ?? nil, !title.isEmpty {
            return title
        }
        return item.previewItemURL?.lastPathComponent
    }

    @objc private func closeButtonTapped() {
        if let onClose {
            onClose()
            return
        }

        delegate?.previewControllerWillDismiss?(self)
        dismiss(animated: true) { [weak self] in
            guard let self else {
                return
            }
            delegate?.previewControllerDidDismiss?(self)
        }
    }
        
    /// Hides the navigation toolbar and observes its `isHidden` state to keep it
    /// hidden if QuickLook tries to show it again.
    private func removeToolbarItems() {
        
        guard mdmSetup?.disableShareMedia() ?? false else {
            return
        }
       
        if let navigationToolbar = navigationController?.toolbar {
            navigationToolbar.isHidden = true
            /// Fires whenever QuickLook changes the toolbar visibility. Keeps it hidden
            /// for the lifetime of this controller.
            if toolbarObservation == nil {
                toolbarObservation = navigationToolbar.observe(\.isHidden) { [weak self] toolbar, change in
                    self?.observeNavigationToolbarHidden(changed: toolbar, change: change)
                }
            }
        }
        
        // Since iOS 26, the share item has moved to the bottom toolbar. Since we cannot observe its visibility directly
        // we use the observation of the visibility of the navigation bar to re-hide its items below.
        if #available(iOS 26.0, *) {
            // We cannot detect which item is the share button, so we just remove all of them.
            toolbarItems = nil
        }
    }
    
    /// KVO handler that re-hides the toolbar whenever QuickLook makes it visible again.
    func observeNavigationToolbarHidden(changed: UIView, change: NSKeyValueObservedChange<Bool>) {
        if navigationController?.toolbar.isHidden == false {
            navigationController?.toolbar.isHidden = true
            
            if #available(iOS 26.0, *) {
                // We cannot detect which item is the share button, so we just remove all of them.
                toolbarItems = nil
            }
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension ThreemaQLPreviewController: UINavigationControllerDelegate {
    /// Intercepts child view controllers pushed by QuickLook (e.g. zip file browser)
    /// and sets up observers to strip share/menu buttons as soon as QuickLook adds them,
    /// including after the navigation bar reappears, on item change, device rotation and on layout changes.
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard viewController !== self,
              let qlPreviewViewController = viewController as? QLPreviewController else {
            return
        }
        
        // Replaces the previous child's observations, they are set up again if the user navigates back to it
        childObservations = [
            /// Fires when the navigation bar is shown or hidden (e.g. user taps the file).
            /// QuickLook re-adds its buttons when the bar reappears, so we strip immediately
            /// and once more after a short delay to catch any late additions.
            navigationController.navigationBar.observe(\.isHidden) { [weak self, weak viewController] _, _ in
                self?.stripButtonsImmediatelyAndDelayed(from: viewController)
            },

            /// Fires when the user changes to a different preview item. QuickLook re-adds
            /// its buttons for each new item, so we strip immediately and after a short delay.
            qlPreviewViewController.observe(\.currentPreviewItemIndex) { [weak self, weak viewController] _, _ in
                self?.stripButtonsImmediatelyAndDelayed(from: viewController)
            },

            /// Fires when the navigation bar resizes (e.g. on device rotation).
            /// QuickLook may re-add buttons after a layout change.
            navigationController.navigationBar.observe(\.bounds) { [weak self, weak viewController] _, _ in
                self?.stripButtons(from: viewController)
            },

            /// Fires when the child view controller's view resizes (e.g. on device rotation).
            /// Ensures buttons are stripped after any layout pass on the child VC.
            viewController.view.observe(\.bounds) { [weak self, weak viewController] _, _ in
                self?.stripButtons(from: viewController)
            },
        ]
    }
    
    /// Resets the preview to the first item after the child VC finishes appearing,
    /// ensuring a consistent starting state when the zip browser is shown.
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard viewController !== self,
              let qlPreviewViewController = viewController as? QLPreviewController else {
            return
        }
        
        qlPreviewViewController.currentPreviewItemIndex = 0
        stripButtons(from: viewController)
    }

    /// Strips buttons immediately and again after a short delay to catch items
    /// that QuickLook adds asynchronously after the triggering event.
    private func stripButtonsImmediatelyAndDelayed(from viewController: UIViewController?) {
        stripButtons(from: viewController)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak viewController] in
            self?.stripButtons(from: viewController)
        }
    }

    /// Removes all share and menu controls from the given view controller's navigation item.
    private func stripButtons(from viewController: UIViewController?) {
        guard let viewController else {
            return
        }
        
        viewController.navigationItem.rightBarButtonItems = []
        viewController.navigationItem.titleView = nil
        viewController.navigationItem.documentProperties = nil
        viewController.navigationItem.titleMenuProvider = nil
        
        viewController.toolbarItems = nil
    }
}
