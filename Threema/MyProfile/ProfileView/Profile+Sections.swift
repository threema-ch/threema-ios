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

import SwiftUI
import ThreemaFramework
import ThreemaMacros

extension ProfileView {
    
    // MARK: - QuickActionsViewSection
    
    struct QuickActionsViewSection: View {
        @EnvironmentObject var model: ProfileViewModel
        @State var isAccessibilityHidden = false
        
        var body: some View {
            Section {
                QuickActionRow {
                    if !TargetManager.isOnPrem {
                        .init(
                            action: shareID,
                            icon: "square.and.arrow.up.fill",
                            title: String.localizedStringWithFormat(
                                #localize("profile_share_id"),
                                TargetManager.localizedAppName
                            ),
                            buttonAccessibilityIdentifier: "share_id_button",
                            accessibilityIdentifier: "share_id"
                        )
                    }
                    
                    .init(
                        action: showQrCode,
                        icon: "qrcode",
                        title: #localize("profile_show_qr_code"),
                        buttonAccessibilityIdentifier: "qr_code_button",
                        accessibilityIdentifier: "qr_code"
                    )
                }
                .listRowInsets(EdgeInsets())
                .background(Color(uiColor: Colors.backgroundGroupedViewController))
                .accessibilityHidden(isAccessibilityHidden)
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
            var vc: UIViewController!
            let dismissQrCodeView: () -> Void = {
                UIView.animate(withDuration: QRCodeView.animationDuration) {
                    qrCodeUiView.alpha = 0
                } completion: { _ in
                    vc.dismiss(animated: false)
                }
            }
            let qrcodeView = QRCodeView(dismiss: dismissQrCodeView).environmentObject(model)
            vc = UIHostingController(rootView: qrcodeView)
            vc.modalPresentationStyle = .overFullScreen
            qrCodeUiView = vc.view
            guard let qrCodeUiView else {
                return
            }

            qrCodeUiView.frame.size.width = currentWindow.view.bounds.width
            qrCodeUiView.frame.size.height = currentWindow.view.bounds.height
            qrCodeUiView.alpha = 0
            qrCodeUiView.backgroundColor = .clear
            qrCodeUiView.accessibilityIdentifier = "qr_code"
            currentWindow.present(vc, animated: false)
  
            UIView.animate(withDuration: QRCodeView.animationDuration) {
                qrCodeUiView.alpha = 1
            }
        }
    }
    
    // MARK: - LinkedDataSection
    
    struct LinkedDataSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                ModalNavigationLink(destination: {
                    viewController(
                        model.linkMobileNoPending
                            ? "enterCodeViewController"
                            : "linkMobileNoViewController"
                    )
                    .wrappedModalNavigationView
                }, label: {
                    ListItem(
                        title: #localize("profile_linked_phone"),
                        subTitle: model.linkedMobile
                    )
                }, onDismiss: model.load, fullscreen: false)
                
                ModalNavigationLink(destination: {
                    viewController("linkEmailViewController")
                        .wrappedModalNavigationView
                }, label: {
                    ListItem(
                        title: #localize("profile_linked_email"),
                        subTitle: model.linkedEmail
                    )
                }, onDismiss: model.load, fullscreen: false)
            } footer: {
                Text(String(format: #localize("myprofile_link_email_phone_footer"), TargetManager.appName))
            }
            .disabled(model.readOnlyProfile)
        }
    }
    
    // MARK: - IsThreemaSafeSection

    struct ThreemaSafeSection: View {
        @EnvironmentObject var model: ProfileViewModel
        
        var body: some View {
            Section {
                LockedNavigationLink(shouldNavigate: $model.shouldNavigateToSafeSetup, label: {
                    ListItem(
                        title: String.localizedStringWithFormat(
                            #localize("safe_setup_backup_title"),
                            TargetManager.localizedAppName
                        ),
                        subTitle: #localize(model.isThreemaSafeActivated ? "On" : "Off")
                    )
                }, destination: {
                    ThreemaSafeSection.safe
                })
                .disabled(model.mdmSetup?.isSafeBackupDisable() ?? false)
                .accessibilityIdentifier("safe_cell")
            } footer: { footer }
        }
        
        @ViewBuilder
        private var footer: some View {
            Text(
                !(model.mdmSetup?.isSafeBackupDisable() ?? true)
                    ? String.localizedStringWithFormat(
                        #localize("safe_enable_explain_short"),
                        TargetManager.localizedAppName
                    )
                    : #localize("disabled_by_device_policy")
            )
        }
        
        static var safe: some View {
            uiViewController(viewController("safeSetupViewController"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(String.localizedStringWithFormat(
                    #localize("safe_setup_backup_title"),
                    TargetManager.localizedAppName
                ))
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
                        title: #localize("profile_id_export")
                    )
                }
                .disabled(model.disableBackups)
                if !TargetManager.isOnPrem {
                    LockedModalNavigationLink {
                        revocationKey
                    } label: {
                        ListItem(
                            title: #localize("revocation_password"),
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
                    delegate: model.delegateHandler.revocationKey
                )
        }
        
        var exportID: some View {
            ProfileView
                .viewController(
                    "backupPasswordViewController",
                    from: "CreatePassword"
                )
                .wrappedModalNavigationView(
                    delegate: model.delegateHandler.exportID
                )
        }
        
        @ViewBuilder
        private var footer: some View {
            if model.disableBackups || model.readOnlyProfile {
                Text(#localize("disabled_by_device_policy"))
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
                        title: #localize("public_key")
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
                title: #localize("my_profile_delete_cell_title")
            )
            .foregroundColor(.red)
        }
        
        var body: some View {
            Section(footer: footer) {
                if KKPasscodeLock.shared().isPasscodeRequired() {
                    ButtonNavigationLink {
                        isAlertPresented.toggle()
                    } label: {
                        label
                    }.alert(
                        #localize("delete_identity_passcode_title"),
                        isPresented: $isAlertPresented,
                        actions: { },
                        message: {
                            Text(#localize("delete_identity_passcode_message"))
                        }
                    )
                }
                else {
                    ModalNavigationLink(destination: {
                        DeleteRevokeView()
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
