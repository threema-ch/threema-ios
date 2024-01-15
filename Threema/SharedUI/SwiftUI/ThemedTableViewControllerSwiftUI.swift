//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import SwiftUI
import ThreemaFramework

class ThemedTableViewControllerSwiftUI: ThemedTableViewController {
    private var observing = false
    private var state: ConnectionState = .disconnected
    private var hostedViewVC: UIViewController
    private var navTitle: String
    
    init(navTitle: String, hostedView: some View) {
        self.hostedViewVC = UIHostingController(rootView: hostedView)
        self.navTitle = navTitle
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .allButUpsideDown
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorThemeChanged),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
        BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        
        let hostedView = hostedViewVC.view
        hostedView!.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostedViewVC)
        hostedViewVC.didMove(toParent: self)
        let wrappedView = WrappedView(view: hostedView!)
        view = wrappedView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if presentingViewController != nil {
            // We are modally presented and have a done button on the right side
            if let rbitem = hostedViewVC.navigationItem.rightBarButtonItem {
                navigationItem.leftBarButtonItems?.append(rbitem)
            }
        }
        
        navigationItem.largeTitleDisplayMode = UINavigationItem
            .LargeTitleDisplayMode(rawValue: (UserSettings.shared()?.largeTitleDisplayMode)!)!
        
        registerObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        unregisterObserver()
    }
        
    @objc func colorThemeChanged(notification: Notification) {
        BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        navigationController?.navigationBar
            .largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: Colors.text]
    }
    
    private func updateTitle() {
        let navHeight = navigationController!.navigationBar.frame.size.height
        let textInNavBar = navigationItem.prompt != nil
        if (navHeight <= BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight <= BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            navigationItem.titleView != nil {
            showTitleLogo()
        }
        else if (navHeight > BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight > BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            navigationItem.titleView == nil {
            showTitleText()
        }
    }
}

extension ThemedTableViewControllerSwiftUI {
    // MARK: UIScrollViewDelegate
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let _ = navigationController?.navigationBar.prefersLargeTitles else {
            return
        }
        updateTitle()
    }
}

extension ThemedTableViewControllerSwiftUI {
    // MARK: Private Functions
    
    private func registerObserver() {
        if observing == false {
            ServerConnector.shared().registerConnectionStateDelegate(delegate: self)
            observing = true
        }
    }
    
    private func unregisterObserver() {
        if observing == true {
            ServerConnector.shared().unregisterConnectionStateDelegate(delegate: self)
            observing = false
        }
    }
}

protocol ThreemaTitleUpdatable: UIViewController {
    func showTitleLogo()
    func showTitleText()
}

// MARK: - ThemedTableViewControllerSwiftUI + ThreemaTitleUpdatable

extension ThemedTableViewControllerSwiftUI: ThreemaTitleUpdatable {
    func showTitleLogo() {
        if navigationItem.titleView == nil {
            BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        }
    }
    
    func showTitleText() {
        navigationItem.titleView = nil
        title = navTitle
    }
}

class WrappedView: UIView {

    private(set) var view: UIView!

    init(view: UIView) {
        self.view = view
        super.init(frame: CGRect.zero)
        addSubview(view)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        view.frame = bounds
    }
}

// MARK: - ThemedTableViewControllerSwiftUI + ConnectionStateDelegate

extension ThemedTableViewControllerSwiftUI: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.state = state
        }
    }
}
