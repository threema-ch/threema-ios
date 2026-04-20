import SwiftUI
import ThreemaFramework
import UIKit

final class StatusNavigationController: UINavigationController {
    
    private let shouldAllowBranding: Bool
    private let notificationCenter: any NotificationCenterProtocol
    
    private var notificationObserver: (any NSObjectProtocol)?

    private lazy var promptTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(promptTapped))

    /// In contrast to the color, the prompt is based on a VC basis, so if we navigate, we must set the prompt again.
    private var currentPrompt: String?
    
    // MARK: - Lifecycle
    
    deinit {
        notificationCenter.removeObserver(self)
    }

    init(
        shouldAllowBranding: Bool = true,
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default
    ) {
        self.shouldAllowBranding = shouldAllowBranding
        self.notificationCenter = notificationCenter
        super.init(
            navigationBarClass: StatusNavigationBar.self,
            toolbarClass: nil
        )
        observeNavigationBarChanges()
    }
    
    override convenience init(rootViewController: UIViewController) {
        self.init(
            shouldAllowBranding: true,
            notificationCenter: NotificationCenter.default
        )
        viewControllers = [rootViewController]
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateNavigationBarContent()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationBarContent()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateNavigationBarContent()
    }
    
    private func observeNavigationBarChanges() {
        if #unavailable(iOS 26.0) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateNavigationBarColor),
                name: Notification.Name(kNotificationNavigationBarColorShouldChange),
                object: nil
            )
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNavigationBarPrompt),
            name: Notification.Name(kNotificationNavigationItemPromptShouldChange),
            object: nil
        )
    }

    // MARK: Helpers

    @objc func updateNavigationBarPrompt(notification: Notification? = nil) {
        Task { @MainActor in
            if NavigationBarPromptHandler.shouldShowPrompt() {
                var duration: Int?
                if let notification {
                    duration = notification.object as? Int
                }
                
                let newPrompt = NavigationBarPromptHandler.getCurrentPrompt(
                    duration: duration
                )
                currentPrompt = newPrompt
            }
            else {
                currentPrompt = nil
            }
            updateNavigationBarContent()
        }
    }
    
    private func updatePrompt() {
        if NavigationBarPromptHandler.shouldShowPrompt() {
            topViewController?.navigationItem.prompt = currentPrompt
            navigationBar.addGestureRecognizer(promptTapGestureRecognizer)
        }
        else {
            topViewController?.navigationItem.prompt = nil
            navigationBar.removeGestureRecognizer(promptTapGestureRecognizer)
        }
        // This fixes the nav bar having the wrong height after resetting the prompts, plus it leads to the
        // branding image appearing on launch.
        navigationBar.setNeedsLayout()
    }
    
    @objc func updateNavigationBarColor(forceOpaque: Bool = false) {
        Task { @MainActor in
            if #unavailable(iOS 26.0) {
                if !isModalInPresentation, let color = Colors.colorForNavigationBackground() {
                    let coloredAppearance = UINavigationBarAppearance()
                    coloredAppearance.configureWithOpaqueBackground()
                    coloredAppearance.backgroundColor = color
                    navigationBar.standardAppearance = coloredAppearance
                    navigationBar.scrollEdgeAppearance = coloredAppearance
                }
                else {
                    let opaqueAppearance = UINavigationBarAppearance()
                    opaqueAppearance.configureWithOpaqueBackground()
                    let transparentAppearance = UINavigationBarAppearance()
                    transparentAppearance.configureWithTransparentBackground()
                    navigationBar.standardAppearance = opaqueAppearance
                    navigationBar.scrollEdgeAppearance = forceOpaque ? opaqueAppearance : transparentAppearance
                }
                
                updateNavigationBarContent()
            }
        }
    }
    
    @objc func updateNavigationBarContent() {

        guard !isEditing else {
            hideTitleView()
            return
        }
        
        defer {
            updatePrompt()
        }
        
        guard shouldAllowBranding,
              let topViewController,
              /// Ensure branding is only applied on the rootViewController
              topViewController == viewControllers.first,
              let navHeight = topViewController.navigationController?.navigationBar.frame.size.height
        else {
            return
        }

        let textInNavBar = NavigationBarPromptHandler.shouldShowPrompt()
        
        if (navHeight <= BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight <= BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            topViewController.navigationItem.titleView != nil {
            hideTitleView()
        }
        else if (navHeight > BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight > BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            topViewController.navigationItem.titleView == nil {
            BrandingUtils.updateTitleLogo(of: topViewController.navigationItem, in: self)
        }
    }
    
    // MARK: Private helpers
    
    private func hideTitleView() {
        topViewController?.navigationItem.titleView = nil
    }
    
    @objc private func promptTapped() {
        Task { @MainActor in
            // 1-1 Calls
            if NavigationBarPromptHandler.isCallActiveInBackground {
                VoIPCallStateManager.shared.presentCallViewController()
            }
            // Web
            else if NavigationBarPromptHandler.isWebActive {
                let vc = UIHostingController(rootView: ThreemaWebSettingsView())
                showViewController(vc)
            }
            // Group Calls
            else if NavigationBarPromptHandler.isGroupCallActive {
                GlobalGroupCallManagerSingleton.shared.showGroupCallViewController()
            }
        }
    }
    
    private func showViewController(_ vc: UIViewController) {
        let appDelegate = AppDelegate.shared()
        if let appCoordinator = appDelegate?.appCoordinator as? AppCoordinator {
            appCoordinator.showModal(for: vc)
        }
        else {
            let modalVC = ModalNavigationController()
            modalVC.showDoneButton = true
            modalVC.pushViewController(vc, animated: true)
            AppDelegate.shared().currentTopViewController().show(modalVC, sender: nil)
        }
    }
}
