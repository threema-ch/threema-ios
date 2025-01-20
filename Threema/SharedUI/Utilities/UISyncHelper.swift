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
import MBProgressHUD
import PromiseKit
import ThreemaMacros

class UISyncHelper {
    private let viewController: UIViewController
    private let navigationController: UINavigationController?
    private let progressString: String
    
    private var execProfileSync: (() -> Void)?
    
    private var promise: Promise<Void>?
    private var seal: Resolver<Void>?
    
    private var shouldShowGraceTime = true
    
    init(
        viewController: UIViewController,
        progressString: String,
        navigationController: UINavigationController? = nil
    ) {
        self.viewController = viewController
        self.navigationController = navigationController
        self.progressString = progressString
    }
    
    public func execute(profile: ProfileStore.Profile) -> Promise<Void> {
        let (newPromise, newSeal) = Promise<Void>.pending()
        promise = newPromise
        seal = newSeal
        
        execProfileSync = {
            self.showProgress()
            
            let profileStore = ProfileStore()
            profileStore.syncAndSave(profile)
                .done {
                    self.successHandler()
                }
                .catch { error in
                    self.errorHandler(error: error)
                }
        }
        
        execProfileSync?()
        
        return newPromise
    }
    
    private func showProgress() {
        DispatchQueue.main.async {
            let hud = MBProgressHUD(view: self.getViewForHud())
            self.getViewForHud().addSubview(hud)
            hud.graceTime = self.shouldShowGraceTime ? 0.5 : 0
            hud.minShowTime = 1
            hud.label.text = self.progressString
            hud.show(animated: true)
        }
    }
    
    private func errorHandler(error: Error) {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.getViewForHud(), animated: true)
            
            let title = #localize("sync_error_title")
            var message = #localize("sync_error_general_message")
            var canRetry = true
            
            if let error = error as? TaskExecutionTransactionError, error == .sameTransactionInProgress {
                message = #localize("sync_error_same_transaction_error")
                canRetry = false
            }
            
            if canRetry {
                UIAlertTemplate.showAlert(
                    owner: self.viewController,
                    title: title,
                    message: message,
                    titleOk: #localize("retry"),
                    actionOk: { _ in
                        // Do nothing and let the user hit done again
                        self.shouldShowGraceTime = false
                        self.execProfileSync?()
                    },
                    titleCancel: #localize("cancel")
                ) { _ in
                    // Dismiss without saving
                    self.seal?.reject(error)
                }
            }
            else {
                UIAlertTemplate.showAlert(owner: self.viewController, title: title, message: message) { _ in
                    self.seal?.reject(error)
                }
            }
        }
    }
    
    private func successHandler() {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.getViewForHud(), animated: true)
            self.seal?.fulfill_()
        }
    }
    
    private func getViewForHud() -> UIView {
        var view = viewController.view!
        if let navController = navigationController, navController.view != nil {
            view = navController.view!
        }
        return view
    }
}
