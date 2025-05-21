//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaFramework
import ThreemaMacros

@objc class ContactListBaseViewController: ThemedTableViewController {
    
    // MARK: - Properties
    
    weak var itemsDelegate: ContactListActionDelegate?
    var businessInjector: BusinessInjectorProtocol = BusinessInjector.ui
    
    // MARK: - Lifecycle
    
    init(itemsDelegate: ContactListActionDelegate? = nil) {
        self.itemsDelegate = itemsDelegate
        super.init(nibName: nil, bundle: nil)
        
        // This fixes the inset for the footer
        additionalSafeAreaInsets.bottom = 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // This fixes transparency issues with the navigation bar
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top + 2), animated: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Pull to refresh
    
    private func configureRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(startPullToRefresh), for: .valueChanged)
        tableView.refreshControl = control
    }
    
    @objc private func startPullToRefresh() {
        tableView.refreshControl?.isUserInteractionEnabled = false
        syncContacts()
    }
    
    private func endPullToRefresh() {
        tableView.refreshControl?.isUserInteractionEnabled = true
        tableView.refreshControl?.endRefreshing()
    }
    
    // TODO: (IOS-4425) Some logic below should be in ContactStore and needs major clean-up
    func syncContacts() {
        GatewayAvatarMaker().refreshForced()
        
        let contactStore = businessInjector.contactStore
        
        guard businessInjector.userSettings.syncContacts else {
            if TargetManager.isBusinessApp {
                contactStore.synchronizeAddressBook(forceFullSync: true, ignoreMinimumInterval: true) { [weak self] _ in
                    self?.updateWorkData()
                } onError: { [weak self] _ in
                    self?.updateWorkData()
                }
            }
            else {
                NotificationPresenterWrapper.shared.present(type: .contactSyncOffWarning)
                endPullToRefresh()
            }
            return
        }
        
        contactStore.synchronizeAddressBook(forceFullSync: true, ignoreMinimumInterval: true) { [weak self] granted in
            
            guard let self else {
                return
            }
            
            if !granted {
                UIAlertTemplate.showOpenSettingsAlert(
                    owner: self,
                    noAccessAlertType: .contacts,
                    openSettingsCompletion: nil
                )
            }
            
            if TargetManager.isBusinessApp {
                updateWorkData()
            }
            else {
                endPullToRefresh()
                if granted {
                    NotificationPresenterWrapper.shared.present(type: .contactSyncSuccess)
                }
            }
            
        } onError: { error in
            if let nsError = error as? NSError, nsError.code == 429, TargetManager.isBusinessApp {
                UIAlertTemplate
                    .showAlert(
                        owner: self,
                        title: nil,
                        message: TargetManager
                            .isBusinessApp ? #localize("pull_to_sync_429_message_work") :
                            #localize("pull_to_sync_429_message")
                    )
                self.endPullToRefresh()
            }
            else {
                if TargetManager.isBusinessApp {
                    self.updateWorkData()
                }
                else {
                    NotificationPresenterWrapper.shared.present(type: .contactSyncFailed)
                    self.endPullToRefresh()
                }
            }
            DDLogError("[ContactList] Address book sync failed: \(error?.localizedDescription ?? "nil")")
        }
    }
    
    private func updateWorkData() {
        WorkDataFetcher.checkUpdateWorkDataForce(true, sendForce: true) { [weak self] in
            NotificationPresenterWrapper.shared.present(type: .contactSyncSuccess)
            self?.endPullToRefresh()
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            
            if let nsError = error as? NSError, nsError.code == 401 || nsError.code == 409 {
                UIAlertTemplate
                    .showAlert(
                        owner: self,
                        title: nil,
                        message: #localize("pull_to_sync_429_message_work")
                    ) { _ in
                        NotificationPresenterWrapper.shared.present(type: .updateWorkDataFailed)
                    }
            }
            else {
                NotificationPresenterWrapper.shared.present(type: .workSyncFailed)
            }
            endPullToRefresh()
            DDLogError("[ContactList] Update work data failed: \(error?.localizedDescription ?? "nil")")
        }
    }
}
