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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaFramework
import UIKit

@objc class StatusNavigationBar: UINavigationBar {
    
    // MARK: - Private Properties
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        
        return recognizer
    }()
    
    // MARK: - Subviews
    
    private lazy var statusView = UIView(frame: CGRect(x: 0, y: frame.size.height - 2, width: frame.width, height: 2))
    
    private lazy var tapView = UIView(frame: .zero)
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(statusView)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNavigationBar),
            name: Notification.Name(kNotificationNavigationBarColorShouldChange),
            object: nil
        )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        statusView.frame = CGRect(x: 0, y: frame.size.height - 2, width: frame.width, height: 2)
        updateStatusView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        ServerConnector.shared().unregisterConnectionStateDelegate(delegate: self)
    }
    
    private func configure() {
        addObservers()
        ServerConnector.shared().registerConnectionStateDelegate(delegate: self)
        addSubview(statusView)
        updateStatusView()
    }
    
    // MARK: - Private Functions
    
    @objc private func updateNavigationBar() {
        DispatchQueue.main.async { [self] in
            if NavigationBarPromptHandler.shouldShowPrompt() {
                addGestureRecognizer(tapGestureRecognizer)
            }
            else {
                removeGestureRecognizer(tapGestureRecognizer)
            }
            Colors.update(navigationBar: self)
            updateStatusView()
        }
    }
    
    private func updateStatusView() {
        DispatchQueue.main.async { [self] in
            switch ServerConnector.shared().connectionState {
            case .disconnecting, .disconnected, .connecting:
                if ProcessInfoHelper.isRunningForScreenshots {
                    statusView.backgroundColor = .systemGreen
                    statusView.isHidden = true
                }
                else {
                    statusView.backgroundColor = .systemRed
                    statusView.isHidden = false
                }
           
            case .connected:
                statusView.backgroundColor = .systemOrange
                statusView.isHidden = false

            case .loggedIn:
                statusView.backgroundColor = .systemGreen
                statusView.isHidden = true
            }
        }
    }
    
    @objc private func tapped() {
        Task { @MainActor in
            // 1-1 Calls
            if NavigationBarPromptHandler.isCallActiveInBackground {
                VoIPCallStateManager.shared.presentCallViewController()
            }
            // Web
            else if NavigationBarPromptHandler.isWebActive {
                let webVC = AppDelegate.getSettingsStoryboard().instantiateViewController(identifier: "ThreemaWeb")
                showViewController(webVC)
            }
            // Group Calls
            else if NavigationBarPromptHandler.isGroupCallActive {
                GlobalGroupCallsManagerSingleton.shared.showGroupCallViewController()
            }
        }
    }
    
    private func showViewController(_ vc: UIViewController) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let mainTabBarController = AppDelegate.getMainTabBarController() as? MainTabBarController else {
                return
            }
            mainTabBarController.showModal(vc)
        }
        else {
            let modalVC = ModalNavigationController()
            modalVC.showDoneButton = true
            modalVC.pushViewController(vc, animated: true)
            AppDelegate.shared().currentTopViewController().show(modalVC, sender: nil)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension StatusNavigationBar: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        updateStatusView()
    }
}
