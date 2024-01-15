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

import Foundation
import MBProgressHUD
import SwiftUI
import ThreemaFramework

struct ProfileView: View {
    @ObservedObject var model = ProfileViewModel()
    
    var body: some View {
        GeometryReader { proxy in
            DynamicHeader { placeHolder in
                VStack {
                    List {
                        placeHolder(proxy)
                        QuickActionsViewSection()
                        ThreemaSaveSection()
                        IDSection()
                        LinkedDataSection()
                        PublicKeySection()
                        RemoveIDAndDataSection()
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            model.load()
                        }
                    }
                }
            }
            .environmentObject(model)
        }
    }
}

extension ProfileView {
    func createProfileViewController() -> UIViewController {
        Controller(self)
    }
    
    class Controller: ThemedTableViewControllerSwiftUI {
        init(_ profileView: ProfileView = ProfileView()) {
            super.init(navTitle: "myIdentity".localized, hostedView: profileView)
            setup(profileView.model)
        }
        
        private func setup(_ model: ProfileViewModel) {
            model.titleUpdateDelegate = self
            
            let editBtn = UIBarButtonItem(systemItem: .edit, primaryAction: .init(handler: { _ in
                if UserSettings.shared().enableMultiDevice,
                   BusinessInjector().serverConnector.connectionState != .loggedIn {
                    
                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: "not_connected_for_edit_profile_title".localized,
                        message: "not_connected_for_edit_profile_message".localized
                    )
                }
                else {
                    let vc = ProfileView.viewController("editProfileViewController")
                    let mvc = ModalNavigationController(rootViewController: vc)
                    mvc.modalDelegate = model.delegateHandler
                    ModalPresenter.present(mvc, on: self.navigationController!)
                }
            }))
            
            editBtn.accessibilityLabel = "edit_profile".localized
            editBtn.accessibilityTraits = .none
            navigationItem.leftBarButtonItem = editBtn
            
            if ScanIdentityController.canScan() {
                let btn = UIBarButtonItem(
                    image: BundleUtil.imageNamed("QRScan"),
                    primaryAction: .init(handler: { _ in
                        guard let disableAddContact = model.mdmSetup?.disableAddContact(), disableAddContact else {
                            let scanIdentity = ScanIdentityController()
                            scanIdentity.containingViewController = self.navigationController!
                            scanIdentity.startScan()
                            
                            BusinessInjector().contactStore
                                .synchronizeAddressBook(
                                    forceFullSync: true,
                                    ignoreMinimumInterval: false,
                                    onCompletion: nil
                                )
                            
                            return
                        }
                        
                        UIAlertTemplate.showAlert(
                            owner: self,
                            title: "",
                            message: "disabled_by_device_policy".localized
                        )
                    }), menu: nil
                )
                
                btn.accessibilityLabel = "scan_identity".localized
                navigationItem.rightBarButtonItem = btn
            }
        }
    }
}
