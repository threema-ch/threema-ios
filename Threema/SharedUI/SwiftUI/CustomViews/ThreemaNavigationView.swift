//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Combine
import SwiftUI
import ThreemaFramework
@_spi(Advanced) import SwiftUIIntrospect

///
/// `NavigationView` with a custom `UINavigationBar` for displaying the `ConnectionState`. The `titleView` is updated
/// according to the `NavigationBarBrandingMode`.
///
struct ThreemaNavigationView<Content: View>: View {
    
    // MARK: - NavigationBarBrandingMode
    
    enum NavigationBarBrandingMode {
        /// Large NavigationBar with updating `titleView` with logo/title on scroll.
        /// The NavigationBar `height` is used to determine the logo/title transition.
        /// Transitions only happen for `.large` NavigationBars
        /// `.normal` is the default behaviour
        case normal
        /// Compact NavigationBar, transitioning the `titleView` between logo and title according to the specified
        /// scrolling `threshold`.
        /// The title is only shown if the `contentOffset` of the `UIScrollView` is smaller then the provided threshold.
        /// Intended for `.inline` NavigationBars
        case custom(threshold: CGFloat)
        /// Does not automatically update the `titleView` at all.
        /// Instead use the `EnvironmentObject` of `ThreemaNavigationBarBranding` and use `hide()` and `show()` as
        /// needed.
        ///
        /// # Example usage:
        ///
        /// ```swift
        ///     struct ContentView: View {
        ///         @EnvironmentObject var branding: ThreemaNavigationBarBranding
        ///         var body: some View {
        ///             ThreemaNavigationView(.manual, title: "Manual") {
        ///                 List {
        ///                     Button("Hide") { branding.hide() }
        ///                     Button("Show") { branding.show() }
        ///                 }
        ///             }
        ///         }
        ///     }
        /// ```
        ///
        /// Works with any `NavigationBarItem.TitleDisplayMode`
        case manual
    }
    
    // MARK: - Properties
    
    private let content: Content
    private let branding: NavigationBarBrandingMode
    
    @Weak private var customNavigationBar: StatusNavigationBar?
    @Weak private var navigationController: UINavigationController?
    
    // MARK: - States
    
    @State private var cancellable: Set<AnyCancellable> = []
    
    @State private var shouldShowTitleText = true {
        willSet {
            guard let navigationItem, let _ = navigationController?.navigationBar.prefersLargeTitles else {
                return
            }
            
            if !newValue {
                if navigationItem.titleView == nil {
                    BrandingUtils.updateTitleLogo(in: navigationController)
                }
            }
            else {
                navigationItem.titleView = nil
            }
        }
    }
    
    @State private var lastContentOffset: CGPoint = .zero {
        didSet {
            updateTitle()
        }
    }
    
    /// Threema navigation view
    /// - Parameters:
    ///   - branding: How the title/logo transition should behave
    ///   - content: A closure returning the content of the view.
    init(_ branding: NavigationBarBrandingMode = .normal, @ViewBuilder content: @escaping () -> Content) {
        self.content = content()
        self.branding = branding
    }
    
    // MARK: - Body
    
    var body: some View {
        contentView
            .onReceive(\.colorChanged) { _ in
                navigationController.map { nc in
                    nc.navigationBar
                        .largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label]
                    for vc in nc.viewControllers {
                        BrandingUtils.updateTitleLogo(of: vc.navigationItem, in: nc)
                    }
                }
            }
            .onReceive(\.notificationBarItemPromptShouldChange, navigationPromptDidChange)
            .wrappedNavigationView
            .navigationViewStyle(.stack)
            .introspect(.navigationView(style: .stack), on: .iOS(.v15...), customize: customize)
    }
    
    // MARK: - Private functions
    
    private var contentView: some View {
        content
            .introspect(.list, on: .iOS(.v13, .v14, .v15), customize: offsetHandler)
            .introspect(.list, on: .iOS(.v16), customize: offsetHandler)
            .introspect(.list, on: .iOS(.v17...), customize: offsetHandler)
            .navigationBarTitleDisplayMode(.large)
            .environmentObject(
                ThreemaNavigationBarBranding {
                    shouldShowTitleText = false
                } hide: {
                    shouldShowTitleText = true
                }
            )
    }
    
    /// Customizes the navigation controller with a custom navigation bar and configures the large title display mode.
    /// - Parameter navigationController: The `UINavigationController` to be customized.
    private func customize(_ navigationController: UINavigationController) {
        guard customNavigationBar == nil, !(navigationController.navigationBar is StatusNavigationBar) else {
            self.navigationController = navigationController
            customNavigationBar = navigationController.navigationBar as? StatusNavigationBar
            return
        }
        customNavigationBar = StatusNavigationBar()
        navigationController.navigationItem.largeTitleDisplayMode = .automatic
        self.navigationController = navigationController
        customNavigationBar.map { bar in
            navigationController.setValue(bar, forKey: "navigationBar")
            bar.prefersLargeTitles = true
        }
        
        // UINavigationBar setup
        if navigationController.presentingViewController != nil {
            // We are modally presented and have a done button on the right side
            if let rbitem = navigationItem?.rightBarButtonItem {
                navigationController.topViewController?.navigationItem.leftBarButtonItems?.append(rbitem)
            }
        }
    }
    
    /// Handles the offset changes of the scroll view and updates the `lastContentOffset`.
    /// It uses a Combine publisher to observe changes to the contentOffset property of the scrollView.
    /// When the contentOffset changes, it checks if the new value is different from the lastContentOffset
    /// and updates it accordingly.
    ///
    /// - Parameter scrollView: The UIScrollView instance whose offset changes are being monitored.
    private func offsetHandler(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            scrollView
                .publisher(for: \.contentOffset)
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .sink { offset in
                    if offset != lastContentOffset {
                        lastContentOffset = offset
                    }
                }
                .store(in: &cancellable)
        }
    }
    
    /// Update the Title based on the `UINavigationBar` `height`
    private func updateTitle() {
        func normal() {
            guard let navigationController else {
                return
            }
            let navHeight = navigationController.navigationBar.frame.size.height
            let navigationItem = navigationController.topViewController?.navigationItem
            let textInNavBar = (navigationItem?.prompt != nil)
            
            shouldShowTitleText = (navHeight <= BrandingUtils.compactNavBarHeight && !textInNavBar) ||
                (navHeight <= BrandingUtils.compactPromptNavBarHeight && textInNavBar)
        }
        
        switch branding {
        case .normal:
            normal()
        case let .custom(threshold):
            shouldShowTitleText = lastContentOffset.y > threshold
        case .manual:
            // use ThreemaNavigationBarBranding instead
            break
        }
    }
    
    private func navigationPromptDidChange(_ notification: Notification) {
        navigationItem?.prompt = NavigationBarPromptHandler.getCurrentPrompt(duration: notification.object as? NSNumber)

        navigationController?.view.setNeedsLayout()
        navigationController?.view.layoutIfNeeded()
        navigationController?.view.setNeedsDisplay()
        
        // Update navigation controllers view controllers view when height changes
        /// Fixes incorrect content offset after the navigation bar updates its height
        /// We only noticed this in chat view controller but other views in general should suffer from similar issues.
        /// Thus we don't check specifically for chat view controller.
        navigationController?.viewControllers.forEach { $0.view.setNeedsLayout() }
    }
}

// MARK: - Helper

extension ThreemaNavigationView {
    var navigationItem: UINavigationItem? {
        navigationController?.topViewController?.navigationItem
    }
    
    var navigationBar: UINavigationBar? {
        navigationController?.navigationBar
    }
}

// MARK: - ThreemaNavigationBarBranding

/// An observable object that manages the visibility of the navigation bar branding.
/// It provides actions to show and hide the branding elements. Used *only* for the `.manual` case of
/// `NavigationBarBrandingMode`.
class ThreemaNavigationBarBranding: ObservableObject {
    typealias Action = () -> Void
    
    /// show the `ThreemaNavigationView` branding
    let show: Action
    
    /// hide the `ThreemaNavigationView` branding
    let hide: Action
    
    /// Initializes a new `ThreemaNavigationBarBranding` with the provided show and hide actions.
    fileprivate init(
        show: @escaping Action,
        hide: @escaping Action
    ) {
        self.show = show
        self.hide = hide
    }
}
