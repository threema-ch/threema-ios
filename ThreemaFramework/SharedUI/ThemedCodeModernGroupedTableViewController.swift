//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import UIKit

/// Base class for a modern grouped table view (uses inset starting with iOS 13)
///
/// Delegate and data source are not configured. This is a good starting point if you want to use a diffable datasource.
open class ThemedCodeModernGroupedTableViewController: ThemedViewController {
    
    // MARK: - The (table) view
    
    /// The table view set as root view
    open lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return tableView
    }()
    
    // MARK: - Scroll edge appearance for non-large titles
    
    /// The navigation bar is only transparent if scrolled to top when this is set to `true`. The default is `false`
    open var transparentNavigationBarWhenOnTop = false {
        didSet {
            scrollViewDidScroll(tableView)
            
            if transparentNavigationBarWhenOnTop {
                // It's only transparent if there is no call or web session
                navigationItem.scrollEdgeAppearance = Colors.transparentNavigationBarAppearance()
            }
            else {
                navigationItem.scrollEdgeAppearance = Colors.defaultNavigationBarAppearance()
            }
        }
    }
    
    /// At which scroll offset does the navigation bar become opaque
    open var navigationBarOpacityBreakpoint: CGFloat = 20 {
        didSet {
            scrollViewDidScroll(tableView)
        }
    }
    
    /// Offset at which point the navigation bar title is set
    open var navigationBarTitleAppearanceOffset: CGFloat = 140 {
        didSet {
            scrollViewDidScroll(tableView)
        }
    }
    
    // Setting this might also change the tab bar item. Use it carefully.
    override open var title: String? {
        didSet {
            navigationBarTitle = title
        }
    }
    
    public var navigationBarTitle: String? {
        didSet {
            navigationItem.accessibilityLabel = navigationBarTitle
            scrollViewDidScroll(tableView)
        }
    }
    
    // Implementation detail
    
    // MARK: - Lifecycle
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Not supported. Just call init().")
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadView() {
        // Do NOT call `super`!
        view = tableView
    }
    
    override open func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
        
        Colors.update(tableView: tableView)
    }
}

// MARK: - UIScrollViewDelegate

// swiftformat:disable:next markTypes

extension ThemedCodeModernGroupedTableViewController: UIScrollViewDelegate {
    
    // Since iOS 13 there is a `scrollEdgeAppearance` property on `UINavigationBar` and
    // `UINavigationBarItem` that manages the navigation bar appearance when scrolled to the top.
    // According to the WWDC Video and documentation this should always work (also see Chatinfo in
    // Messages.app and right split view in Settings.app on iPadOS).
    // From my testing and the answer in a Dev Forums question this only works if a large title is
    // displayed. For `largeTitleDisplayMode = .never` it never uses the appearance from
    // `scrollEdgeAppearance`.
    //
    // ## Workaround Attempts
    //
    // - Changing the size of the large title doesn't change the actual height of the large title view
    // - Injecting subviews into the large navigation bar is probably not safe (maybe check out this
    //   article: https://uptech.team/blog/build-resizing-image-in-navigation-bar-with-large-title)
    //
    // ## This Workaround
    //
    // We change the `standardAppearance` depending on the scroll offset and also show/hide the title.
    //
    // Limitations:
    // - Transition between appearances is not animated (a solution based on the scroll position
    //   like in Messages.app would be nice)
    // - iOS 13+ only (probably an issue with every possible solution). In iOS 12 the appearance is
    //   anyway different as there are only full screen modal views
    //
    // ## Resources
    //
    // - Documentation:
    //   https://developer.apple.com/documentation/uikit/uinavigationbar/3198027-scrolledgeappearance
    // - WWDC 2019 "Modernizing Your UI for iOS 13": https://developer.apple.com/videos/play/wwdc2019/224/
    // - Dev Forums "scrollEdgeAppearance not applied when largeTitleDisplayMode = .never":
    //   https://developer.apple.com/forums/thread/121574
    
    // MARK: UIScrollViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard transparentNavigationBarWhenOnTop else {
            navigationItem.standardAppearance = Colors.defaultNavigationBarAppearance()
            navigationItem.scrollEdgeAppearance = Colors.defaultNavigationBarAppearance()
            navigationItem.title = navigationBarTitle
            return
        }
        
        let adjustedYOffset = scrollView.contentOffset.y + view.safeAreaInsets.top
        navigationItem.title = adjustedYOffset < navigationBarTitleAppearanceOffset ? nil : navigationBarTitle
                
        if adjustedYOffset < navigationBarOpacityBreakpoint {
            // It's only transparent if there is no call or web session
            navigationItem.standardAppearance = Colors.transparentNavigationBarAppearance()
        }
        else {
            navigationItem.standardAppearance = Colors.defaultNavigationBarAppearance()
        }
        // It's only transparent if there is no call or web session
        navigationItem.scrollEdgeAppearance = Colors.transparentNavigationBarAppearance()
    }
}
