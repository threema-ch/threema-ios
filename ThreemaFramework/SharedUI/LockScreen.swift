//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

@objc class LockScreen: NSObject, JKLLockScreenViewControllerDelegate, JKLLockScreenViewControllerDataSource {
    
    // MARK: - Properties
    
    private lazy var newPassCodeViewController: JKLLockScreenViewController = {
        let lockScreenViewController = JKLLockScreenViewController(
            nibName: NSStringFromClass(JKLLockScreenViewController.self),
            bundle: BundleUtil.frameworkBundle()
        )
        
        lockScreenViewController.lockScreenMode = .new
        lockScreenViewController.delegate = self
        lockScreenViewController.dataSource = self
        
        return lockScreenViewController
    }()
    
    private lazy var passCodeViewController: JKLLockScreenViewController = {
        let lockScreenViewController = JKLLockScreenViewController(
            nibName: NSStringFromClass(JKLLockScreenViewController.self),
            bundle: BundleUtil.frameworkBundle()
        )
        
        lockScreenViewController.lockScreenMode = .extension
        lockScreenViewController.delegate = self
        lockScreenViewController.dataSource = self
        
        return lockScreenViewController
    }()
    
    private lazy var legacyPassCodeNavigationController: ModalNavigationController = {
        let modalNavigationController = ModalNavigationController(rootViewController: passCodeViewController)
        modalNavigationController.isNavigationBarHidden = true
        modalNavigationController.modalPresentationStyle = .fullScreen
        
        return modalNavigationController
    }()
    
    private var enteredCorrectly: (() -> Void)?
    private var isLockScreenController: Bool
    
    // MARK: - Lifecycle
    
    @objc init(isLockScreenController: Bool) {
        self.isLockScreenController = isLockScreenController
        super.init()
    }
    
    // MARK: - JKLLockScreenViewControllerDelegate & JKLLockScreenViewControllerDataSource
    
    @objc func presentLockScreenView(
        viewController: UIViewController,
        style: UIModalPresentationStyle = .overFullScreen,
        enteredCorrectly: @escaping () -> Void
    ) {
        self.enteredCorrectly = enteredCorrectly
        
        passCodeViewController.modalPresentationStyle = style
        
        // This is used to set a passcode after a safe-restore when tapping on a private conversation
        if KKPasscodeLock.shared().isPasscodeRequired() {
            viewController.present(passCodeViewController, animated: true)
        }
        else {
            viewController.present(newPassCodeViewController, animated: true)
        }
    }

    @objc func didPasscodeEnteredCorrectly(_ viewController: JKLLockScreenViewController!) {
        enteredCorrectly?()
    }
        
    @objc func allowTouchIDLockScreenViewController(_ lockScreenViewController: JKLLockScreenViewController!) -> Bool {
        KKPasscodeLock.shared().isTouchIDOn()
    }
    
    @objc func lockScreenViewController(
        _ lockScreenViewController: JKLLockScreenViewController!,
        pincode: String!
    ) -> Bool {
        isLockScreenController
    }
    
    @objc func shouldEraseApplicationData(_ viewController: JKLLockScreenViewController!) {
        AppDelegate.shared().eraseApplicationData(viewController)
    }
}
