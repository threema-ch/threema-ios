//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

extension ProfileView {
    
    // MARK: - QuickActionsViewSection
    
    struct QuickActionsViewSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                ZStack {
                    Color(uiColor: Colors.backgroundGroupedViewController)
                    QuickActionRow {
                        if ThreemaApp.current != .onPrem {
                            .init(
                                action: shareID,
                                icon: "square.and.arrow.up.fill",
                                title: "profile_share_id".localized,
                                accessibilityIdentifier: "share_id"
                            )
                        }
                        
                        .init(
                            action: showQrCode,
                            icon: "qrcode",
                            title: "profile_show_qr_code".localized,
                            accessibilityIdentifier: "qr_code"
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
            }
        }
        
        private func shareID() {
            model.share([model.shareThreemaID])
        }
        
        private func showQrCode() {
            guard let currentWindow = AppDelegate.shared().currentTopViewController() else {
                return
            }
            
            var qrCodeUiView: UIView!
            let dismissQrCodeView: () -> Void = {
                UIView.animate(withDuration: 0.3) {
                    qrCodeUiView.alpha = 0
                } completion: { _ in
                    qrCodeUiView.removeFromSuperview()
                }
            }
            let qrcodeView = QRCodeView(dismiss: dismissQrCodeView).environmentObject(model)
            qrCodeUiView = UIHostingController(rootView: qrcodeView).view
            guard let qrCodeUiView else {
                return
            }
            qrCodeUiView.frame.size.width = screenWidth
            qrCodeUiView.frame.size.height = screenHeight
            qrCodeUiView.alpha = 0
            qrCodeUiView.backgroundColor = .clear
            currentWindow.view.addSubview(qrCodeUiView)
            
            UIView.animate(withDuration: 0.3) {
                qrCodeUiView.alpha = 1
            }
        }
    }
    
    // MARK: - LinkedDataSection
    
    struct LinkedDataSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                ModalNavigationLink {
                    viewController(
                        model.linkMobileNoPending
                            ? "enterCodeViewController"
                            : "linkMobileNoViewController"
                    )
                    .wrappedModalNavigationView
                } label: {
                    ListItem(
                        title: "profile_linked_phone".localized,
                        subTitle: model.linkedMobile
                    )
                } onDismiss: {
                    model.load()
                }
                
                ModalNavigationLink {
                    viewController("linkEmailViewController")
                        .wrappedModalNavigationView
                } label: {
                    ListItem(
                        title: "profile_linked_email".localized,
                        subTitle: model.linkedEmail
                    )
                } onDismiss: {
                    model.load()
                }
            } footer: {
                Text(String(format: "myprofile_link_email_phone_footer".localized, ThreemaApp.appName))
            }
            .disabled(model.readOnlyProfile)
        }
    }
    
    // MARK: - IsThreemaSaveSection

    struct ThreemaSaveSection: View {
        @EnvironmentObject var model: ProfileViewModel
    
        var body: some View {
            Section {
                LockedNavigationLink(shouldNavigate: $model.shouldNavigateToSafeSetup, label: {
                    ListItem(
                        title: "Threema Safe",
                        subTitle: (model.isThreemaSafeActivated ? "On" : "Off").localized
                    )
                }, destination: {
                    uiViewController {
                        viewController("safeSetupViewController")
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Threema Safe")
                })
                .disabled(model.mdmSetup?.isSafeBackupDisable() ?? false)
            } footer: { footer }
        }
        
        @ViewBuilder
        private var footer: some View {
            Text(
                BundleUtil.localizedString(
                    forKey: !(model.mdmSetup?.isSafeBackupDisable() ?? true)
                        ? "safe_enable_explain_short"
                        : "disabled_by_device_policy"
                )
            )
        }
    }
    
    // MARK: - IDSection
    
    struct IDSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                LockedModalNavigationLink {
                    exportID
                } label: {
                    ListItem(
                        title: "profile_id_export".localized
                    )
                }
                .disabled(model.disableBackups)
                if ThreemaApp.current != .onPrem {
                    LockedModalNavigationLink {
                        revocationKey
                    } label: {
                        ListItem(
                            title: "revocation_password".localized,
                            subTitle: model.revocationDetail
                        )
                    }
                    .disabled(model.readOnlyProfile)
                }
            } footer: { footer }
        }
        
        var revocationKey: some View {
            ProfileView
                .viewController(
                    "backupPasswordViewController",
                    from: "CreatePassword"
                )
                .wrappedModalNavigationView(
                    delegate: model.delegateHandler.createPassword(for: .revocationKey)
                )
        }
        
        var exportID: some View {
            ProfileView
                .viewController(
                    "backupPasswordViewController",
                    from: "CreatePassword"
                )
                .wrappedModalNavigationView(
                    delegate: model.delegateHandler.createPassword(for: .exportID)
                )
        }
        
        @ViewBuilder
        private var footer: some View {
            if model.disableBackups || model.readOnlyProfile {
                Text("disabled_by_device_policy".localized)
            }
        }
    }
    
    // MARK: - PublicKeySection
    
    struct PublicKeySection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                ButtonNavigationLink {
                    showPublicKey()
                } label: {
                    ListItem(
                        title: "public_key".localized
                    )
                }
            }
        }
        
        private func showPublicKey() {
            PublicKeyView(
                identity: model.publicKey.identity,
                publicKey: model.publicKey.key
            ).show()
        }
    }
    
    // MARK: - RemoveIDAndDataSection

    struct RemoveIDAndDataSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        @State private var isAlertPresented = false
        
        private var label: some View {
            ListItem(
                title: "my_profile_delete_cell_title".localized
            )
            .foregroundColor(Color.red)
        }
        
        var body: some View {
            Section(footer: footer) {
                if KKPasscodeLock.shared().isPasscodeRequired() {
                    ButtonNavigationLink {
                        isAlertPresented.toggle()
                    } label: {
                        label
                    }.alert(
                        "delete_identity_passcode_title".localized,
                        isPresented: $isAlertPresented,
                        actions: { },
                        message: {
                            Text("delete_identity_passcode_message".localized)
                        }
                    )
                }
                else {
                    ModalNavigationLink(destination: {
                        DeleteRevokeInfoView()
                    }, label: {
                        label
                    }, onDismiss: model.load, fullscreen: true)
                }
            }
            .disabled(model.readOnlyProfile)
        }
        
        var footer: some View {
            VStack { }.frame(height: 44)
        }
    }
}

extension ProfileView {
    
    static func viewController(
        _ identifier: String? = nil,
        from storyboard: String = "MyIdentityStoryboard"
    ) -> UIViewController {
        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        guard let identifier else {
            return storyboard.instantiateInitialViewController() ?? UIViewController()
        }
        
        return storyboard.instantiateViewController(withIdentifier: identifier)
    }
}
