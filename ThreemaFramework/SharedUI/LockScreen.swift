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

import CocoaLumberjackSwift
import Foundation
import SwiftUI

final class LockScreen: NSObject, JKLLockScreenViewControllerDelegate, JKLLockScreenViewControllerDataSource {
    
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
    
    fileprivate lazy var passCodeViewController: JKLLockScreenViewController = {
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
    
    fileprivate var enteredCorrectly: (() -> Void)?
    private var enteredIncorrectly: (() -> Void)?
    fileprivate var unlockCancelled: (() -> Void)?
    fileprivate var didDismissAfterSuccess: (() -> Void)?
    
    private let isLockScreenController: Bool
    
    // MARK: - Lifecycle
    
    @objc init(isLockScreenController: Bool) {
        self.isLockScreenController = isLockScreenController
        super.init()
    }
    
    // MARK: - JKLLockScreenViewControllerDelegate & JKLLockScreenViewControllerDataSource
    
    @objc func presentLockScreenViewObjC(
        viewController: UIViewController,
        style: UIModalPresentationStyle,
        enteredCorrectly: (() -> Void)?,
        didDismissAfterSuccess: (() -> Void)?
    ) {
        
        presentLockScreenView(
            viewController: viewController,
            style: style,
            enteredCorrectly: enteredCorrectly,
            didDismissAfterSuccess: didDismissAfterSuccess
        )
    }
    
    func presentLockScreenView(
        viewController: UIViewController,
        style: UIModalPresentationStyle = .automatic,
        enteredCorrectly: (() -> Void)? = nil,
        enteredIncorrectly: (() -> Void)? = nil,
        unlockCancelled: (() -> Void)? = nil,
        didDismissAfterSuccess: (() -> Void)? = nil
    ) {
        self.enteredCorrectly = enteredCorrectly
        self.enteredIncorrectly = enteredIncorrectly
        self.unlockCancelled = unlockCancelled
        self.didDismissAfterSuccess = didDismissAfterSuccess

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
    
    @objc func didPasscodeEnteredIncorrectly(_ viewController: JKLLockScreenViewController!) {
        enteredIncorrectly?()
    }
    
    @objc func unlockWasCancelledLockScreenViewController(_ lockScreenViewController: JKLLockScreenViewController!) {
        unlockCancelled?()
    }
    
    func didPasscodeViewDismiss(_ viewController: JKLLockScreenViewController!) {
        didDismissAfterSuccess?()
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

// MARK: - SwiftUI

/// A lock screen view where the passcode can be entered (or biometrics used if enabled)
struct LockScreenView: UIViewControllerRepresentable {
    
    /// Passcode was entered correctly
    ///
    /// A sheet will be dismissed automatically at least when another sheet is presented. Note that this most likely
    /// works, because in SwiftUI only one sheet can be presented at the same time. So this might break if this
    /// limitation is lifted.
    let codeEnteredCorrectly: (() -> Void)?
    
    /// Lock screen view was canceled. A sheet will be dismissed automatically
    let cancelled: (() -> Void)?
    
    /// Lock screen view was dismissed with correct code
    let didDismissAfterSuccess: (() -> Void)?
    
    init(codeEnteredCorrectly: (() -> Void)?, cancelled: (() -> Void)?, didDismissAfterSuccess: (() -> Void)? = { }) {
        self.codeEnteredCorrectly = codeEnteredCorrectly
        self.cancelled = cancelled
        self.didDismissAfterSuccess = didDismissAfterSuccess
    }
    
    // enteredIncorrectly doesn't seem to work at all (the delegate is not called)
    private let lockScreen = LockScreen(isLockScreenController: false)
    
    func makeUIViewController(context: Context) -> some UIViewController {
        lockScreen.enteredCorrectly = {
            codeEnteredCorrectly?()
        }
        lockScreen.unlockCancelled = {
            cancelled?()
        }
        lockScreen.didDismissAfterSuccess = {
            didDismissAfterSuccess?()
        }
        return lockScreen.passCodeViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // no-op
    }
}

struct LockScreenView_Preview: PreviewProvider {
    static var previews: some View {
        LockScreenView(codeEnteredCorrectly: nil, cancelled: nil)
    }
}
