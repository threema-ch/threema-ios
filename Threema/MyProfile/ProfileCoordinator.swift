import Combine
import Coordinator
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class ProfileCoordinator: NSObject, Coordinator, CurrentDestinationHolderProtocol {

    // MARK: - Internal destination

    enum InternalDestination: Equatable {
        case editProfile
        case scanQRCode
        case qrCode
        case shareID(sourceView: UIView)
        case backups
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

    var currentDestination: InternalDestination?

    // MARK: - Routers

    private weak var presentingViewController: ThreemaSplitViewController?
    private let businessInjector: any BusinessInjectorProtocol
    private let shareActivityRouter: any ShareActivityRouterProtocol
    private let modalRouter: any ModalRouterProtocol
    private let passcodeRouter: any PasscodeRouterProtocol
    
    private lazy var mdmSetup = MDMSetup()
    private lazy var appFlavor = AppFlavorService()
    private lazy var safeConfigManager = SafeConfigManager()
    private lazy var serverApiConnector = ServerAPIConnector()
    private lazy var safeApiService = SafeApiService()
    private lazy var deviceCapabilitiesManager = DeviceCapabilitiesManager()
    private lazy var appEnvironment = AppEnvironment(businessInjector: businessInjector)

    private lazy var collectionView = ProfileCollectionView { [weak self] in
        self?.currentDestination
    } shouldAllowAutoDeselection: { [weak self] in
        let traitCollection = self?.presentingViewController?.traitCollection
        return traitCollection?.horizontalSizeClass == .compact
    }
    
    private var canAddContact: Bool {
        if TargetManager.isBusinessApp {
            mdmSetup?.disableAddContact() == false
        }
        else {
            true
        }
    }

    private lazy var dataSource: ProfileCollectionViewDataSource = {
        let cellProvider: ProfileCollectionViewDataSource.CellProvider =
            { [weak self] collectionView, indexPath, item in

                if item == .header {
                    let cell: ProfileCollectionViewHeaderCell = collectionView.dequeueCell(for: indexPath)
                    cell.backgroundConfiguration = .clear()
                    cell.coordinator = self
                    cell.updateContent()
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
                    
                    if item.isDestructive {
                        content.textProperties.color = .systemRed
                    }
                    
                    if item.isInteractionDisabled {
                        content.textProperties.color = .secondaryLabel
                    }
                    
                    if let accessibilityIdentifier = item.accessibilityIdentifier {
                        cell.accessibilityIdentifier = accessibilityIdentifier
                    }
                    
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

        let tab = ThreemaTab(.profile)
        viewController.tabBarItem = tab.tabBarItem
        viewController.title = tab.title

        return viewController
    }()

    private(set) lazy var rootNavigationController = StatusNavigationController()

    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: profileViewController,
        splitViewController: presentingViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )

    private lazy var safeStore = SafeStore(
        safeConfigManager: safeConfigManager,
        serverApiConnector: serverApiConnector,
        groupManager: businessInjector.groupManager,
        myIdentityStore: businessInjector.myIdentityStore
    )

    private lazy var safeManager = SafeManager(
        safeConfigManager: safeConfigManager,
        safeStore: safeStore,
        safeAPIService: safeApiService
    )

    // MARK: - Lifecycle

    init(
        presentingViewController: ThreemaSplitViewController,
        businessInjector: any BusinessInjectorProtocol,
        shareActivityRouter: any ShareActivityRouterProtocol,
        modalRouter: any ModalRouterProtocol,
        passcodeRouter: any PasscodeRouterProtocol
    ) {
        self.presentingViewController = presentingViewController
        self.businessInjector = businessInjector
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
        
        setupNavigationBarItems()
        observeIncomingSync()
    }

    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }

        switch destination {
        case .editProfile:
            showEditProfile()
            
        case .scanQRCode:
            showScanner()
            
        case .qrCode:
            showQRCode()

        case let .shareID(sourceView):
            shareID(sourceView: sourceView)

        case .backups:
            showBackups()

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
        case .editProfile, .scanQRCode, .qrCode, .shareID, .revocationPassword, .publicKey, .revokeDelete:
            break
        case .backups, .linkPhone, .linkMail:
            currentDestination = destination
        }

        profileViewController.updateSelection()
    }
    
    func navigateToThreemaSafe() {
        show(.backups)
        showBackups(.threemaSafe)
    }

    func dismiss() {
        presentingViewController?.presentedViewController?.dismiss(animated: true)
    }

    // MARK: - Private functions

    private var cancellables: Set<AnyCancellable> = []
    
    private func showEditProfile() {
        if businessInjector.userSettings.enableMultiDevice,
           businessInjector.serverConnector.connectionState != .loggedIn,
           let presentingViewController {
            UIAlertTemplate.showAlert(
                owner: presentingViewController,
                title: #localize("not_connected_for_edit_profile_title"),
                message: #localize("not_connected_for_edit_profile_message")
            )
        }
        else {
            let viewController = EditProfileViewController()
            modalRouter.present(viewController)
        }
    }
    
    private func showScanner() {
        MainActor.assumeIsolated { [weak self] in
            guard let self else {
                return
            }
            
            if canAddContact {
                let viewModel = QRCodeScannerViewModel(
                    mode: .identity,
                    audioSessionManager: AudioSessionManager(),
                    systemFeedbackManager: SystemFeedbackManager(
                        deviceCapabilitiesManager: deviceCapabilitiesManager,
                        settingsStore: businessInjector.settingsStore
                    ),
                    systemPermissionsManager: SystemPermissionsManager()
                )
                let rootView = QRCodeScannerView(model: viewModel)
                let viewController = UIHostingController(rootView: rootView)
                viewModel.onCompletion = { [weak self] result in
                    self?.handleScannerResult(result)
                }
                viewModel.onCancel = { [weak self] in
                    self?.presentingViewController?.dismiss(animated: true)
                }
                modalRouter.present(viewController, animated: true)
            }
            else {
                guard let presentingViewController else {
                    return
                }
                
                UIAlertTemplate.showAlert(
                    owner: presentingViewController,
                    title: "",
                    message: #localize("disabled_by_device_policy")
                )
            }
        }
    }
    
    @MainActor
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
                    settingsStore: businessInjector.settingsStore
                )
            )
            model.onCompletion = { [weak self] verifiedContact in
                self?.presentingViewController?.dismiss(animated: true) {
                    guard let verifiedContact else {
                        return
                    }
                    
                    let name = Notification.Name(kNotificationShowContact)
                    let userInfo = [kKeyContact: verifiedContact]
                    NotificationCenter.default.post(
                        name: name,
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
            let rootView = ContactIdentityProcessingView(model: model)
            let viewController = UIHostingController(rootView: rootView)
            
            presentingViewController?.show(viewController, sender: self)

        case let .identityLink(url: url):
            presentingViewController?.dismiss(animated: true) {
                URLHandler().handle(url, hideAppChooser: true)
            }

        default:
            break
        }
    }

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
            "\(shareText): \(THREEMA_ID_SHARE_LINK)\(businessInjector.myIdentityStore.identity ?? "")"
        shareActivityRouter.present(
            items: [combinedShareText],
            sourceView: sourceView
        )
    }

    private func showBackups(_ additionalRoute: BackupsViewModel.Route? = nil) {
        MainActor.assumeIsolated { [weak self] in
            self?.passcodeRouter.requireAuthenticationIfNeeded { [weak self] in
                guard let self, let mdmSetup = MDMSetup() else {
                    return
                }
                let model = BackupsViewModel(
                    appFlavor: AppFlavorService(),
                    mdmSetup: mdmSetup,
                    safeManager: safeManager
                )
                let rootView = BackupsView(model: model)
                let vc = UIHostingController(rootView: rootView)
                presentingViewController?.show(vc, sender: nil)

                let cancellable = model.routePublisher.sink { [weak self] route in
                    switch route {
                    case .threemaSafe: self?.showThreemaSafe()
                    case .idExport: self?.showPasswordForIDExport()
                    }
                }

                cancellables.insert(cancellable)

                /// If an `additionalRoute` is available, forward it to the
                /// view model, so it can be properly displayed.
                additionalRoute.map(model.routePublisher.send)
            }
        }
    }

    private func showThreemaSafe() {
        MainActor.assumeIsolated { [weak self] in
            self?.passcodeRouter.requireAuthenticationIfNeeded { [weak self] in
                guard let self, let mdmSetup = MDMSetup() else {
                    return
                }

                let model = ThreemaSafeDashboardViewModel(
                    appFlavor: appFlavor,
                    myIdentityStore: BusinessInjector.ui.myIdentityStore,
                    mdmSetup: mdmSetup,
                    notificationCenter: NotificationCenter.default,
                    safeConfigManager: safeConfigManager,
                    safeManager: safeManager,
                    safeStore: safeStore
                )

                let rootView = ThreemaSafeDashboardView(model: model)
                let vc = UIHostingController(rootView: rootView)
                presentingViewController?.viewControllers.last?.show(vc, sender: nil)
            }
        }
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
        let identityStore = businessInjector.myIdentityStore
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
        guard !passcodeRouter.isPasscodeRequired() else {
            if let presentingViewController {
                UIAlertTemplate.showAlert(
                    owner: presentingViewController,
                    title: #localize("delete_identity_passcode_title"),
                    message: #localize("delete_identity_passcode_message")
                )
            }
            return
        }

        let deleteRevokeView = DeleteRevokeView { [weak self] in
            self?.dismiss()
        }

        /// Due to ``DeleteRevokeView`` having an inner flow,
        /// we don't want to add this to a ``UINavigationController``,
        /// but present the ``UIHostingController`` directly.
        let vc = DarkModeUIHostingController(rootView: deleteRevokeView)
        vc.modalPresentationStyle = .overFullScreen
        modalRouter.rootViewController.present(vc, animated: true)
    }
    
    private func setupNavigationBarItems() {
        let leftBarButtonItem = UIBarButtonItem.editButton(target: self, selector: #selector(editProfile))
        profileViewController.navigationItem.leftBarButtonItem = leftBarButtonItem
        
        guard deviceCapabilitiesManager.supportsRecordingVideo else {
            return
        }
        
        let rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "qrcode.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(scanQRCode)
        )
        profileViewController.navigationItem.rightBarButtonItem = rightBarButtonItem
    }
    
    private func observeIncomingSync() {
        appEnvironment.profileSyncPublisher
            .sink { [weak self] _ in
                self?.incomingSync()
            }
            .store(in: &cancellables)
    }
    
    @objc private func editProfile() {
        show(.editProfile)
    }
    
    @objc private func scanQRCode() {
        show(.scanQRCode)
    }
    
    private func incomingSync() {
        collectionView.reloadData()
        
        NotificationPresenterWrapper.shared.present(
            type: NotificationPresenterType(
                notificationText: #localize("incoming_profile_sync_title"),
                notificationStyle: .none
            ),
            subtitle: #localize("incoming_profile_sync_message")
        )
    }
}

// MARK: - ProfileCollectionViewDataSource.Row

extension ProfileCollectionViewDataSource.Row {
    fileprivate func toProfileDestination() -> ProfileCoordinator.InternalDestination? {
        switch self {
        case .header:
            assertionFailure("Should not be possible to select.")
            return nil
        case .backups:
            return .backups
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
