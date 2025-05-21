//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import Coordinator
import Foundation
import SwiftUI
import ThreemaMacros

final class ProfileCoordinator: NSObject, Coordinator {
    
    // MARK: - Internal destination

    typealias CoordinatorDestination = InternalDestination
    
    enum InternalDestination: Equatable {
        case qrCode
        case shareID(sourceView: UIView)
        case threemaSafe
        case idExport
        case revocationPassword
        case linkPhone
        case linkMail
        case publicKey
        case revokeDelete
    }
    
    // MARK: - Coordinator
    
    weak var parentCoordinator: (any Coordinator)?
    var childCoordinators: [any Coordinator] = []
    
    private(set) var currentDestination: InternalDestination?
    
    private lazy var rootVC = ProfileViewController(coordinator: self)

    // MARK: - Public properties
    
    var horizontalSizeClass: UIUserInterfaceSizeClass = .unspecified {
        didSet {
            guard oldValue != horizontalSizeClass else {
                return
            }
            horizontalSizeClassDidChange()
        }
    }
    
    // MARK: - Lifecycle

    init(parentCoodinator: any Coordinator) {
        self.parentCoordinator = parentCoodinator
    }
    
    func rootViewController() -> UIViewController {
        rootVC
    }
    
    // MARK: - Updates

    func checkDetailVC() {
        guard horizontalSizeClass == .regular else {
            return
        }
        
        show(currentDestination ?? .threemaSafe)
    }
    
    private func horizontalSizeClassDidChange() {
        rootVC.updateSelection()
    }
    
    // MARK: - Presentation
    
    func show(_ destination: Destination) {
        parentCoordinator?.show(destination)
    }
    
    func show(_ destination: Destination.AppDestination.ProfileDestination) { }
    
    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }
        
        switch destination {
        case .qrCode:
            showQRCode()
            
        case let .shareID(sourceView):
            shareID(sourceView: sourceView)
            
        case .threemaSafe:
            showThreemaSafe()
            
        case .idExport:
            showPasswordForIDExport()
            
        case .revocationPassword:
            showPasswordForRevocation()
            
        case .linkPhone:
            showLinkedPhoneNumber()
            
        case .linkMail:
            showLinkMail()
            
        case .publicKey:
            showPublicKey()
            
        case .revokeDelete:
            showRevokeDelete()
        }
        
        // We do not update the current destination for modals
        switch destination {
        case .qrCode, .shareID, .idExport, .revocationPassword, .publicKey,
             .revokeDelete:
            break
        case .threemaSafe, .linkPhone, .linkMail:
            currentDestination = destination
        }
        
        rootVC.updateSelection()
    }
    
    func show(_ viewController: UIViewController, style: CordinatorNavigationStyle) {
        parentCoordinator?.show(viewController, style: style)
    }
    
    func shareActivity(_ items: [Any], sourceView: UIView?) {
        parentCoordinator?.shareActivity(items, sourceView: sourceView)
    }

    func dismiss() {
        parentCoordinator?.dismiss()
    }
    
    // MARK: - Private functions
    
    private func showQRCode() {
        let vc = UIHostingController(rootView: QrCodeView(coordinator: self))
        show(vc, style: .modal())
    }
    
    private func shareID(sourceView: UIView) {
        let shareText = String.localizedStringWithFormat(
            #localize("profile_share_id_text"),
            TargetManager.localizedAppName
        )
        let combinedShareText =
            "\(shareText): \(THREEMA_ID_SHARE_LINK)\(BusinessInjector.ui.myIdentityStore.identity ?? "")"
        shareActivity([combinedShareText], sourceView: sourceView)
    }
    
    private func showThreemaSafe() {
        let vc = UIStoryboard(name: "MyIdentityStoryboard", bundle: nil)
            .instantiateViewController(identifier: "safeSetupViewController")
        show(vc, style: .passcode(style: .show))
    }
    
    private func showPasswordForIDExport() {
        let vc = UIHostingController(rootView: PasswordCreationView(
            coordinator: self,
            title: #localize("profile_id_export"),
            footer: #localize("password_description_backup")
        ) { password in
            self.showExportedID(password: password)
        })
        show(vc, style: .passcode(style: .modal()))
    }
    
    private func showExportedID(password: String) {
        let vc = UIHostingController(rootView: IDExportView(coordinator: self, password: password))
        show(vc, style: .modal())
    }
    
    private func showPasswordForRevocation() {
        let vc = UIHostingController(rootView: PasswordCreationView(
            coordinator: self,
            title: #localize("revocation_password"),
            footer: #localize("revocation_password_description")
        ) { password in
            RevocationKeyManager.shared.setPassword(password)
        })
        
        show(vc, style: .passcode(style: .modal()))
    }
    
    private func showLinkedPhoneNumber() {
        let vc = UIHostingController(rootView: LinkPhoneNumberDeciderView())
        show(vc)
    }
    
    private func showLinkMail() {
        let vc = UIHostingController(rootView: LinkEmailDeciderView())
        show(vc)
    }
    
    private func showPublicKey() {
        let identityStore = BusinessInjector.ui.myIdentityStore
        let view = PublicKeyView(identity: identityStore.identity, publicKey: identityStore.publicKey) { [weak self] in
            self?.parentCoordinator?.dismiss()
        }
        let vc = UIViewController()
        vc.view = view
        show(vc, style: .modal(stlye: .overFullScreen, transition: .crossDissolve))
    }
    
    private func showRevokeDelete() {
        // TODO: (IOS-5213) Disable passcode alert
        let vc = UIHostingController(rootView: DeleteRevokeView())
        show(vc, style: .modal(stlye: .overFullScreen))
    }
}

// MARK: - UINavigationControllerDelegate

extension ProfileCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // If we navigate back to the rootVC, we reset the destination
        if navigationController.topViewController == rootVC, horizontalSizeClass == .compact {
            currentDestination = nil
        }
    }
}
