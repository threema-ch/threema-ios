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

import CocoaLumberjackSwift
import Combine
import Foundation
import MBProgressHUD
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
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

    private let businessInjector: BusinessInjectorProtocol
    private let safeStore: SafeStore
    private let safeConfigManager: SafeConfigManager
    private let serverAPIConnector: ServerAPIConnector
    private let deviceCapabilitiesManager: DeviceCapabilitiesManagerProtocol

    private(set) var mdmSetup = MDMSetup()

    private lazy var safeManager: SafeManager = .init(
        safeConfigManager: self.safeConfigManager,
        safeStore: self.safeStore,
        safeApiService: SafeApiService()
    )

    var canScan: Bool {
        deviceCapabilitiesManager.supportsRecordingVideo
    }

    lazy var delegateHandler: DelegateHandler = .init(didDismissModal: load)

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
        businessInjector.myIdentityStore.linkMobileNoPending
    }

    public var publicKey: (key: Data, identity: String) {
        (key: businessInjector.myIdentityStore.publicKey, identity: businessInjector.myIdentityStore.identity)
    }
    
    public var shareThreemaID: String {
        "\(String.localizedStringWithFormat(#localize("profile_share_id_text"), TargetManager.localizedAppName)):\(THREEMA_ID_SHARE_LINK)\(publicKey.identity)"
    }
   
    convenience init() {
        self.init(
            businessInjector: BusinessInjector.ui,
            safeConfigManager: SafeConfigManager(),
            serverAPIConnector: ServerAPIConnector(),
            deviceCapabilitiesManager: DeviceCapabilitiesManager()
        )
    }
    
    init(
        businessInjector: BusinessInjectorProtocol,
        safeConfigManager: SafeConfigManager,
        serverAPIConnector: ServerAPIConnector,
        deviceCapabilitiesManager: DeviceCapabilitiesManager
    ) {
        self.businessInjector = businessInjector
        self.safeConfigManager = safeConfigManager
        self.serverAPIConnector = serverAPIConnector
        self.deviceCapabilitiesManager = deviceCapabilitiesManager
        self.safeStore = .init(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: businessInjector.groupManager,
            myIdentityStore: businessInjector.myIdentityStore
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
        addObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func share(_ items: [Any]) {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let currentWindow = AppDelegate.shared().currentTopViewController() {
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = currentWindow.view
                activityViewController.popoverPresentationController?.sourceRect = CGRectMake(
                    currentWindow.view.bounds.maxX,
                    currentWindow.view.bounds.midY,
                    0,
                    0
                )
            }
            
            currentWindow.present(activityViewController, animated: true)
        }
    }

    func load() {
        loadQRCode()
        loadNickname()
        loadLinkedEmail()
        loadLinkedMobile()
        profileImage = businessInjector.myIdentityStore.resolvedProfilePicture
        loadRevocationDetail()

        isThreemaSafeActivated = safeManager.isActivated
    }
    
    func incomingSync() {
        load()
        
        NotificationPresenterWrapper.shared.present(
            type: .init(
                notificationText: #localize("incoming_profile_sync_title"),
                notificationStyle: .none
            ),
            subtitle: #localize("incoming_profile_sync_message")
        )
    }

    func scanAction() {
        if canAddContact {
            showQRCodeScanner()
        }
        else {
            UIAlertTemplate.showAlert(
                owner: topViewController,
                title: "",
                message: #localize("disabled_by_device_policy")
            )
        }
    }

    // MARK: - Helpers

    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadRevocationDetail),
            name: Notification.Name(kRevocationPasswordUIRefresh),
            object: nil
        )
    }
    
    private func loadLinkedEmail() {
        guard let linkedEmail = businessInjector.myIdentityStore.linkedEmail else {
            self.linkedEmail = ""
            return
        }
        
        if businessInjector.myIdentityStore.linkEmailPending {
            self.linkedEmail = #localize("(pending)")
            
            serverAPIConnector.checkLinkEmailStatus(
                businessInjector.myIdentityStore as! MyIdentityStore,
                email: linkedEmail
            ) { [weak self] linked in
                guard let self, linked else {
                    return
                }
                businessInjector.myIdentityStore.linkEmailPending = false
                self.linkedEmail = linkedEmail
            } onError: { _ in }
        }
        else {
            self.linkedEmail = linkedEmail
        }
    }
    
    private func loadLinkedMobile() {
        if businessInjector.myIdentityStore.linkMobileNoPending {
            linkedMobile = #localize("enter_code")
        }
        else {
            if let linkedMobile = businessInjector.myIdentityStore.linkedMobileNo {
                self.linkedMobile = "+\(linkedMobile)"
            }
            else {
                linkedMobile = " "
            }
        }
    }
    
    private func loadQRCode() {
        guard businessInjector.myIdentityStore.isValidIdentity else {
            DDLogWarn("Trying to show QR code for non-valid identity")
            return
        }
        
        let qrString = "3mid:\(publicKey.identity),\(publicKey.key.hexString)"
        qrCodeImage = QRCodeGenerator.generateQRCode(for: qrString, size: AppDelegate.shared().window.frame.width)
    }
    
    private func loadNickname() {
        if let pushFromName = businessInjector.myIdentityStore.pushFromName, !pushFromName.isEmpty {
            nickname = pushFromName
            threemaID = publicKey.identity
        }
        else {
            nickname = publicKey.identity
            threemaID = ""
        }
    }
    
    private func userProfile() -> Data? {
        guard let profilePicture = businessInjector.myIdentityStore.profilePicture,
              let imageData = profilePicture["ProfilePicture"] as? Data else {
            return nil
        }
        return imageData
    }
    
    @objc private func loadRevocationDetail() {
        let updateDetail: () -> Void = { [weak self] in
            guard let setDate = self?.businessInjector.myIdentityStore.revocationPasswordSetDate else {
                self?.revocationDetail = #localize("revocation_password_not_set")
                return
            }
            self?.revocationDetail = DateFormatter.getShortDate(setDate)
        }
        
        guard let _ = businessInjector.myIdentityStore.revocationPasswordLastCheck else {
            serverAPIConnector
                .checkRevocationPassword(
                    for: businessInjector.myIdentityStore as! MyIdentityStore
                ) { [weak self] revocationPasswordSet, lastChanged in
                    self?.businessInjector.myIdentityStore.revocationPasswordLastCheck = Date.now
                    self?.businessInjector.myIdentityStore
                        .revocationPasswordSetDate = revocationPasswordSet ? lastChanged : nil
                    updateDetail()
                
                } onError: { [weak self] _ in
                    self?.revocationDetail = #localize("revocation_check_failed")
                }
            
            return
        }
        
        updateDetail()
    }

    private var topViewController: UIViewController {
        AppDelegate.shared().currentTopViewController() ?? .init()
    }

    private var canAddContact: Bool {
        if TargetManager.isBusinessApp {
            mdmSetup?.disableAddContact() == false
        }
        else {
            true
        }
    }

    private func showQRCodeScanner() {
        let model = QRCodeScannerViewModel(
            mode: .identity,
            audioSessionManager: AudioSessionManager(),
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            ),
            systemPermissionsManager: SystemPermissionsManager()
        )
        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)
        model.onCompletion = { [weak self] result
            in self?.handleScannerResult(result)
        }
        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true)
        }
        topViewController.present(nav, animated: true)
    }

    private func handleScannerResult(_ result: QRCodeScannerViewModel.QRCodeResult) {
        switch result {
        case let .identityContact(identity: id, publicKey: key, expirationDate: date):
            let model = ContactIdentityProcessingViewModel(
                expectedIdentity: nil,
                scannedIdentity: id,
                scannedPublicKey: key,
                scannedExpirationDate: date,
                systemFeedbackManager: SystemFeedbackManager(
                    deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                    settingsStore: BusinessInjector.ui.settingsStore
                )
            )
            model.onCompletion = { [weak self] verifiedContact in
                self?.topViewController.dismiss(animated: true) {
                    if let verifiedContact {
                        let name = Notification.Name(kNotificationShowContact)
                        let userInfo = [kKeyContact: verifiedContact]
                        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
                    }
                }
            }
            let rootView = ContactIdentityProcessingView(model: model)
            let viewController = UIHostingController(rootView: rootView)
            (topViewController as? UINavigationController)?.pushViewController(viewController, animated: true)

        case let .identityLink(url: url):
            topViewController.dismiss(animated: true) {
                URLHandler.handleThreemaDotIDURL(url, hideAppChooser: true)
            }

        default:
            break
        }
    }
}

// MARK: - ProfileViewModel.DelegateHandler

extension ProfileViewModel {
    class DelegateHandler: NSObject {
        private var didDismissModal: () -> Void
        
        init(
            didDismissModal: @escaping () -> Void,
        ) {
            self.didDismissModal = didDismissModal
            super.init()
        }
    }
}

// MARK: - ProfileViewModel.DelegateHandler + ModalNavigationControllerDelegate

extension ProfileViewModel.DelegateHandler: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        didDismissModal()
    }
}
