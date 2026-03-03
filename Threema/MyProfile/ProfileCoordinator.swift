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

final class ProfileCoordinator: NSObject, Coordinator, CurrentDestinationHolding {
    
    // MARK: - Internal destination
    
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
    
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    // MARK: - Routers
    
    private let shareActivityRouter: any ShareActivityRouting
    private let modalRouter: any ModalRouting
    private let passcodeRouter: any PasscodeRouting
    
    var currentDestination: InternalDestination?
    
    private lazy var collectionView = ProfileCollectionView { [weak self] in
        self?.currentDestination
    } shouldAllowAutoDeselection: { [weak self] in
        let traitCollection = self?.presentingViewController?.traitCollection
        return traitCollection?.horizontalSizeClass == .compact
    }

    private lazy var dataSource: ProfileCollectionViewDataSource = {
        let cellProvider: ProfileCollectionViewDataSource.CellProvider =
            { [weak self] collectionView, indexPath, item in
            
                if item == .header {
                    let cell: ProfileCollectionViewHeaderCell = collectionView.dequeueCell(for: indexPath)
                    cell.backgroundConfiguration = .clear()
                    cell.coordinator = self
                    return cell
                }
                else {
                    guard let cell: UICollectionViewListCell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: "Default",
                        for: indexPath
                    ) as? UICollectionViewListCell else {
                        return nil
                    }
                
                    var content = cell.defaultContentConfiguration()
                    content.text = item.title
                    cell.contentConfiguration = content
                    cell.accessories = [.disclosureIndicator()]
                    if let text = item.accessoryText {
                        cell.accessories.append(.label(text: text))
                    }
                    cell.isUserInteractionEnabled = !item.isInteractionDisabled
                    return cell
                }
            }
        
        let dataSource = ProfileCollectionViewDataSource(
            collectionView: collectionView,
            cellProvider: cellProvider
        ) { [weak self] in
            guard let destination = $0.toProfileDestination() else {
                return
            }
            
            self?.show(destination)
        }
        
        return dataSource
    }()
    
    private lazy var profileViewController: ProfileViewController = {
        let viewController = ProfileViewController(
            collectionView: collectionView,
            dataSource: dataSource
        )
        
        let item = ThreemaTabBarController.TabBarItem(.profile)
        viewController.tabBarItem = item.uiTabBarItem
        viewController.title = item.title
        
        return viewController
    }()
    
    private lazy var rootNavigationController = UINavigationController()
        
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: profileViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    private weak var presentingViewController: UIViewController?
    
    // MARK: - Lifecycle

    init(
        presentingViewController: UIViewController,
        shareActivityRouter: any ShareActivityRouting,
        modalRouter: any ModalRouting,
        passcodeRouter: any PasscodeRouting
    ) {
        self.presentingViewController = presentingViewController
        self.shareActivityRouter = shareActivityRouter
        self.modalRouter = modalRouter
        self.passcodeRouter = passcodeRouter
    }
    
    // MARK: - Presentation
    
    func start() {
        rootNavigationController.delegate = navigationDestinationResetter
        
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [profileViewController],
            animated: false
        )
    }
    
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
        
        profileViewController.updateSelection()
    }

    func dismiss() {
        presentingViewController?.presentedViewController?.dismiss(animated: true)
    }
    
    // MARK: - Private functions
    
    private func showQRCode() {
        let vc = UIHostingController(rootView: QrCodeView(coordinator: self))
        modalRouter.present(vc)
    }
    
    private func shareID(sourceView: UIView) {
        let shareText = String.localizedStringWithFormat(
            #localize("profile_share_id_text"),
            TargetManager.localizedAppName
        )
        let combinedShareText =
            "\(shareText): \(THREEMA_ID_SHARE_LINK)\(BusinessInjector.ui.myIdentityStore.identity ?? "")"
        shareActivityRouter.present(
            items: [combinedShareText],
            sourceView: sourceView
        )
    }
    
    private func showThreemaSafe() {
        passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
            let vc = UIStoryboard(
                name: "MyIdentityStoryboard",
                bundle: nil
            ).instantiateViewController(identifier: "safeSetupViewController")
            
            self?.presentingViewController?.show(vc, sender: self)
        })
    }
    
    private func showPasswordForIDExport() {
        passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
            let vc = UIHostingController(rootView: PasswordCreationView(
                coordinator: self,
                title: #localize("profile_id_export"),
                footer: #localize("password_description_backup"),
                passwordCreateButton: #localize("profile_id_export_button")
            ) { password in
                self?.showExportedID(password: password)
            })
            
            self?.modalRouter.present(vc)
        })
    }
    
    private func showExportedID(password: String) {
        let vc = UIHostingController(rootView: IDExportView(coordinator: self, password: password))
        modalRouter.present(vc)
    }
    
    private func showPasswordForRevocation() {
        passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
            let vc = UIHostingController(rootView: PasswordCreationView(
                coordinator: self,
                title: #localize("revocation_password"),
                footer: String.localizedStringWithFormat(
                    #localize("revocation_password_description"),
                    TargetManager.localizedAppName
                ),
                passwordCreateButton: #localize("revocation_password_button")
            ) { password in
                RevocationKeyManager.shared.setPassword(password)
            })
            
            self?.modalRouter.present(vc)
        })
    }
    
    private func showLinkedPhoneNumber() {
        let vc = UIHostingController(rootView: LinkPhoneNumberDeciderView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showLinkMail() {
        let vc = UIHostingController(rootView: LinkEmailDeciderView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showPublicKey() {
        let identityStore = BusinessInjector.ui.myIdentityStore
        let view = PublicKeyView(identity: identityStore.identity, publicKey: identityStore.publicKey) { [weak self] in
            self?.dismiss()
        }
        let vc = UIViewController()
        vc.view = view
        modalRouter.present(
            vc,
            style: .overFullScreen,
            transition: .crossDissolve
        )
    }
    
    private func showRevokeDelete() {
        // TODO: (IOS-5213) Disable passcode alert
        let deleteRevokeView = DeleteRevokeView { [weak self] in
            self?.dismiss()
        }
        
        let vc = UIHostingController(rootView: deleteRevokeView)
        modalRouter.present(vc, style: .overFullScreen)
    }
}

// MARK: - ProfileCollectionViewDataSource.Row

extension ProfileCollectionViewDataSource.Row {
    fileprivate func toProfileDestination() -> ProfileCoordinator.InternalDestination? {
        switch self {
        case .header:
            assertionFailure("Should not be possible to select.")
            return nil
        case .threemaSafe:
            return .threemaSafe
        case .idExport:
            return .idExport
        case .revocationPassword:
            return .revocationPassword
        case .phone:
            return .linkPhone
        case .mail:
            return .linkMail
        case .publicKey:
            return .publicKey
        case .revokeDelete:
            return .revokeDelete
        }
    }
}
