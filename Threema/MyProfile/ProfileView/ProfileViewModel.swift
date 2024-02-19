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

import Combine
import Foundation
import MBProgressHUD
import ThreemaFramework

final class ProfileViewModel: ObservableObject {
    
    @Published var shouldNavigateToSafeSetup = false
    @Published var navigator = Navigator()
    
    @Published private(set) var nickname: String
    @Published private(set) var threemaID: String
    @Published private(set) var linkedEmail: String
    @Published private(set) var qrCodeImage: UIImage
    @Published private(set) var profileImage: UIImage
    @Published private(set) var linkedMobile: String
    @Published private(set) var revocationDetail: String
    @Published private(set) var isThreemaSafeActivated: Bool
 
    private let safeStore: SafeStore
    private let myIdentityStore: MyIdentityStore
    private let serverConnector: ServerConnectorProtocol
    private let safeConfigManager: SafeConfigManager
    private let serverAPIConnector: ServerAPIConnector
    
    private(set) var mdmSetup = MDMSetup(setup: false)
    
    private lazy var safeManager: SafeManager = .init(
        safeConfigManager: self.safeConfigManager,
        safeStore: self.safeStore,
        safeApiService: SafeApiService()
    )
    
    lazy var delegateHandler: DelegateHandler =
        .init(
            updateRevocationDetail: loadRevocationDetail,
            didDismissModal: load
        ) { [weak self] password in
            self?.myIdentityStore.backupIdentity(withPassword: password)
        }
    
    var hasProfile: Bool {
        userProfile() != nil
    }
    
    var readOnlyProfile: Bool {
        mdmSetup?.readonlyProfile() ?? false
    }

    var disableBackups: Bool {
        (mdmSetup?.disableBackups() ?? false) || (mdmSetup?.disableIDExport() ?? false)
    }

    var linkMobileNoPending: Bool {
        myIdentityStore.linkMobileNoPending
    }
    
    public var publicKey: (key: Data, identity: String) {
        (key: myIdentityStore.publicKey, identity: myIdentityStore.identity)
    }
    
    public var shareThreemaID: String {
        "\(BundleUtil.localizedString(forKey: "profile_share_id_text")):\(THREEMA_ID_SHARE_LINK)\(publicKey.identity)"
    }
   
    convenience init() {
        self.init(
            serverConnector: BusinessInjector().serverConnector,
            myIdentityStore: BusinessInjector().myIdentityStore as! MyIdentityStore,
            safeConfigManager: SafeConfigManager(),
            serverAPIConnector: ServerAPIConnector()
        )
    }
    
    init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStore,
        safeConfigManager: SafeConfigManager,
        serverAPIConnector: ServerAPIConnector
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.safeConfigManager = safeConfigManager
        self.serverAPIConnector = serverAPIConnector
        self.safeStore = .init(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: GroupManager()
        )
        self.nickname = ""
        self.threemaID = ""
        self.linkedEmail = ""
        self.linkedMobile = ""
        self.qrCodeImage = UIImage()
        self.profileImage = UIImage()
        self.revocationDetail = "…"
        self.isThreemaSafeActivated = false
        load()
    }
    
    public func share(_ items: [Any]?) {
        if let activityViewController = ActivityUtil.activityViewController(
            withActivityItems: items,
            applicationActivities: nil
        ),
            let currentWindow = AppDelegate.shared().currentTopViewController() {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = currentWindow.view
                activityViewController.popoverPresentationController?.sourceRect = CGRectMake(
                    currentWindow.view.bounds.maxX,
                    currentWindow.view.bounds.center.y,
                    0,
                    0
                )
            }
            
            currentWindow.present(activityViewController, animated: true)
        }
    }
    
    func load() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.loadQRCode()
            self.loadNickname()
            self.loadLinkedEmail()
            self.loadLinkedMobile()
            self.loadProfilePicture()
            self.loadRevocationDetail()
            
            self.isThreemaSafeActivated = self.safeManager.isActivated
        }
    }
    
    func incomingSync() {
        load()
        
        NotificationPresenterWrapper.shared.present(
            type: .init(
                notificationText: BundleUtil.localizedString(forKey: "incoming_profile_sync_title"),
                notificationStyle: .none
            ),
            subtitle: BundleUtil.localizedString(forKey: "incoming_profile_sync_message")
        )
    }
    
    private func loadLinkedEmail() {
        guard let linkedEmail = myIdentityStore.linkedEmail else {
            self.linkedEmail = ""
            return
        }
        
        if myIdentityStore.linkEmailPending {
            self.linkedEmail = BundleUtil.localizedString(forKey: "pending")
            
            serverAPIConnector.checkLinkEmailStatus(myIdentityStore, email: linkedEmail) { [weak self] linked in
                guard let self, linked else {
                    return
                }
                self.myIdentityStore.linkEmailPending = false
                self.linkedEmail = self.myIdentityStore.linkedEmail
            } onError: { _ in }
        }
        else {
            self.linkedEmail = linkedEmail
        }
    }
    
    private func loadLinkedMobile() {
        if myIdentityStore.linkMobileNoPending {
            linkedMobile = BundleUtil.localizedString(forKey: "enter_code")
        }
        else {
            if let linkedMobile = myIdentityStore.linkedMobileNo {
                self.linkedMobile = "+\(linkedMobile)"
            }
            else {
                linkedMobile = " "
            }
        }
    }
    
    private func loadQRCode() {
        guard myIdentityStore.isProvisioned() else {
            return
        }
        
        let qrString = "3mid:\(publicKey.identity),\(publicKey.key.hexString)"
        qrCodeImage = QRCodeGenerator.renderQrCodeString(
            qrString,
            withDimension: Int32(AppDelegate.shared().window.frame.width)
        )
    }
    
    private func loadNickname() {
        if let pushFromName = myIdentityStore.pushFromName, !pushFromName.isEmpty {
            nickname = pushFromName
            threemaID = publicKey.identity
        }
        else {
            nickname = publicKey.identity
            threemaID = ""
        }
    }
    
    private func userProfile() -> Data? {
        guard let profilePicture = myIdentityStore.profilePicture,
              let imageData = profilePicture["ProfilePicture"] as? Data else {
            return nil
        }
        return imageData
    }

    private func loadProfilePicture() {
        let fallbackImage = AvatarMaker.shared().unknownPersonImage() ?? UIImage()
        guard let imageData = userProfile() else {
            profileImage = fallbackImage
            
            return
        }
        profileImage = .init(data: imageData) ?? fallbackImage
    }
    
    private func loadRevocationDetail() {
        let updateDetail: () -> Void = { [weak self] in
            guard let setDate = self?.myIdentityStore.revocationPasswordSetDate else {
                self?.revocationDetail = BundleUtil.localizedString(forKey: "revocation_password_not_set")
                return
            }
            self?.revocationDetail = DateFormatter.getShortDate(setDate)
        }
        
        guard let _ = myIdentityStore.revocationPasswordLastCheck else {
            serverAPIConnector
                .checkRevocationPassword(for: myIdentityStore) { [weak self] revocationPasswordSet, lastChanged in
                    self?.myIdentityStore.revocationPasswordLastCheck = Date.now
                    self?.myIdentityStore.revocationPasswordSetDate = revocationPasswordSet ? lastChanged : nil
                    updateDetail()
                
                } onError: { [weak self] _ in
                    self?.revocationDetail = BundleUtil.localizedString(forKey: "revocation_check_failed")
                }
            
            return
        }
        
        updateDetail()
    }
}

// MARK: - ProfileViewModel.DelegateHandler

extension ProfileViewModel {
    class DelegateHandler: NSObject {
        
        fileprivate let revocationHandler = RevocationKeyHandler()
        private var updateRevocationDetail: () -> Void
        private var backupIdentity: (String) -> (String?)
        private var didDismissModal: () -> Void
        
        lazy var revocationKey: PasswordNavigationDelegate = .init(
            title: BundleUtil.localizedString(forKey: "revocation_password"),
            additionalText: BundleUtil.localizedString(forKey: "revocation_password_description"),
            callback: revocationHandler
        )
        
        lazy var exportID: PasswordNavigationDelegate = .init(
            additionalText: BundleUtil.localizedString(forKey: "password_description_backup"),
            callback: self
        )
        
        init(
            updateRevocationDetail: @escaping () -> Void,
            didDismissModal: @escaping () -> Void,
            backupIdentity: @escaping (String) -> String?
        ) {
            self.updateRevocationDetail = updateRevocationDetail
            self.backupIdentity = backupIdentity
            self.didDismissModal = didDismissModal
            super.init()
            revocationHandler.delegate = self
        }
    }
}

// MARK: - ProfileViewModel.DelegateHandler.PasswordNavigationDelegate

extension ProfileViewModel.DelegateHandler {
    class PasswordNavigationDelegate: NSObject, UINavigationControllerDelegate {
        var title: String?
        var additionalText: String?
        var callback: PasswordCallback?
        
        init(title: String? = nil, additionalText: String? = nil, callback: PasswordCallback? = nil) {
            self.title = title
            self.additionalText = additionalText
            self.callback = callback
        }
        
        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            if let passwordVC = viewController as? BackupPasswordViewController {
                passwordVC.passwordTitle = title ?? ""
                passwordVC.passwordAdditionalText = additionalText ?? ""
            }

            if let passwordVerify = viewController as? BackupPasswordVerifyViewController {
                passwordVerify.passwordCallback = callback
            }
        }
    }
}

// MARK: - ProfileViewModel.DelegateHandler + RevocationKeyDelegate

extension ProfileViewModel.DelegateHandler: RevocationKeyDelegate {
    func revocationKeyChanged() {
        updateRevocationDetail()
    }
}

// MARK: - ProfileViewModel.DelegateHandler + PasswordCallback

extension ProfileViewModel.DelegateHandler: PasswordCallback {
    func passwordResult(_ password: String!, from viewController: UIViewController!) {
        MBProgressHUD.showAdded(to: viewController.view, animated: true)
        DispatchQueue.global(qos: .default).async {
            let backupData = self.backupIdentity(password)
            
            DispatchQueue.main.async {
                MBProgressHUD.hide(for: viewController.view, animated: true)

                let storyBoard: UIStoryboard = AppDelegate.getMainStoryboard()
                let vc = storyBoard
                    .instantiateViewController(
                        withIdentifier: "BackupIdentityViewController"
                    ) as! BackupIdentityViewController
                vc.backupData = backupData

                viewController.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}

// MARK: - ProfileViewModel.DelegateHandler + ModalNavigationControllerDelegate

extension ProfileViewModel.DelegateHandler: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        didDismissModal()
    }
}

extension Notification.Name {
    static let identityLinkedWithMobileNo = Notification.Name("ThreemaIdentityLinkedWithMobileNo")
    static let navigateSafeSetup = Notification.Name(kNotificationShowSafeSetup)
    static let incomingProfileSync = Notification.Name(kNotificationIncomingProfileSynchronization)
}
