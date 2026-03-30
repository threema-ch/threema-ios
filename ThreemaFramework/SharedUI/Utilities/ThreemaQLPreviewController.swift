//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import QuickLook

private class DisableShareUINavigationItem: UINavigationItem {
    override func setRightBarButtonItems(_ items: [UIBarButtonItem]?, animated: Bool) {
        // forbidden to add anything to right
    }
}

public class ThreemaQLPreviewController: QLPreviewController {
    
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
    
    var mdmSetup = MDMSetup()

    var disableShareButton = false
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        disableShareButton = mdmSetup?.disableShareMedia() ?? false
        
        if disableShareButton {
            navigationItem.setRightBarButton(UIBarButtonItem(), animated: false)
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
    }
        
    /// Hides the navigation toolbar and observes its `isHidden` state to keep it
    /// hidden if QuickLook tries to show it again.
    private func removeToolbarItems() {
        if mdmSetup?.disableShareMedia() ?? false, let navigationToolbar = navigationController?.toolbar {
            navigationToolbar.isHidden = true
            /// Fires whenever QuickLook changes the toolbar visibility. Keeps it hidden
            /// for the lifetime of this controller.
            let observation = navigationToolbar.observe(\.isHidden, changeHandler: observeNavigationToolbarHidden)
            observations.append(observation)
        }
    }
    
    /// KVO handler that re-hides the toolbar whenever QuickLook makes it visible again.
    func observeNavigationToolbarHidden(changed: UIView, change: NSKeyValueObservedChange<Bool>) {
        if navigationController?.toolbar.isHidden == false {
            navigationController?.toolbar.isHidden = true
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
        
        /// Fires when the navigation bar is shown or hidden (e.g. user taps the file).
        /// QuickLook re-adds its buttons when the bar reappears, so we strip immediately
        /// and once more after a short delay to catch any late additions.
        observations.append(
            navigationController.navigationBar.observe(\.isHidden) { [weak self, weak viewController] _, _ in
                self?.stripButtonsImmediatelyAndDelayed(from: viewController)
            }
        )

        /// Fires when the user changes to a different preview item. QuickLook re-adds
        /// its buttons for each new item, so we strip immediately and after a short delay.
        observations.append(
            qlPreviewViewController.observe(\.currentPreviewItemIndex) { [weak self, weak viewController] _, _ in
                self?.stripButtonsImmediatelyAndDelayed(from: viewController)
            }
        )

        /// Fires when the navigation bar resizes (e.g. on device rotation).
        /// QuickLook may re-add buttons after a layout change.
        observations.append(
            navigationController.navigationBar.observe(\.bounds) { [weak self, weak viewController] _, _ in
                self?.stripButtons(from: viewController)
            }
        )

        /// Fires when the child view controller's view resizes (e.g. on device rotation).
        /// Ensures buttons are stripped after any layout pass on the child VC.
        observations.append(
            viewController.view.observe(\.bounds) { [weak self, weak viewController] _, _ in
                self?.stripButtons(from: viewController)
            }
        )
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
    }

    /// Strips buttons immediately and again after a short delay to catch items
    /// that QuickLook adds asynchronously after the triggering event.
    private func stripButtonsImmediatelyAndDelayed(from viewController: UIViewController?) {
        stripButtons(from: viewController)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak viewController] in
            self?.stripButtons(from: viewController)
        }
    }

    /// Removes all share and menu controls from the given view controller's navigation item.
    private func stripButtons(from viewController: UIViewController?) {
        viewController?.navigationItem.rightBarButtonItems = []
        viewController?.navigationItem.titleView = nil
        viewController?.navigationItem.documentProperties = nil
        viewController?.navigationItem.titleMenuProvider = nil
    }
}
