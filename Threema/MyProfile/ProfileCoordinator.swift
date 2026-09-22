import Combine
import Coordinator
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class ProfileCoordinator: NSObject, Coordinator {

    // MARK: - Internal destination

    enum InternalDestination: Hashable {
        // Actions and modals (never part of the navigation path)
        case editProfile
        case scanQRCode
        case qrCode
        case shareID
        case workAvailabilityStatus
        case revocationPassword
        case publicKey
        case revokeDelete

        // Path destinations
        case backups
        /// Threema Safe dashboard, always shown on top of `.backups`
        case threemaSafe
        case linkPhone
        case linkMail
    }

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }

    // MARK: - Routers

    private weak var presentingViewController: ThreemaSplitViewController?
    private let businessInjector: any BusinessInjectorProtocol
    private let shareActivityRouter: any ShareActivityRouterProtocol
    private let modalRouter: any ModalRouterProtocol
    private let passcodeRouter: any PasscodeRouterProtocol
    private let router = NavigationRouter()

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

    private lazy var cellProvider: ProfileCollectionViewDataSource.CellProvider = {
        [weak self] collectionView, indexPath, item in

        guard let self else {
            return nil
        }

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

            var content = UIListContentConfiguration.valueCell()
            content.text = item.title

            if item.isDestructive {
                content.textProperties.color = .systemRed
            }

            if item.isInteractionDisabled {
                content.textProperties.color = .secondaryLabel
            }
            let indicator = UICellAccessory.disclosureIndicator()
            cell.accessories = [indicator]

            if let text = item.accessoryText {
                content.secondaryText = text
            }

            if let accessibilityIdentifier = item.accessibilityIdentifier {
                cell.accessibilityIdentifier = accessibilityIdentifier
            }

            if item == .workAvailabilityStatus {
                let manager = businessInjector.workAvailabilityStatusManager
                let category = manager.ownStatus().category

                // Only show label for status other than `.none`
                if category != .none {
                    let attachment = NSTextAttachment()
                    let font = UIFont.preferredFont(forTextStyle: .body)

                    let size = CGSize(width: font.capHeight, height: font.capHeight)
                    attachment.image = UIGraphicsImageRenderer(size: size).image { _ in
                        category.color.setFill()
                        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                    }
                    attachment.bounds = CGRect(origin: .zero, size: size)

                    let attributedText = NSMutableAttributedString(attachment: attachment)
                    attributedText.append(NSAttributedString(string: " \(category.localizedDescription)"))

                    content.secondaryAttributedText = attributedText
                }
            }
            cell.contentConfiguration = content

            cell.isUserInteractionEnabled = !item.isInteractionDisabled
            return cell
        }
    }

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

    private lazy var safeStore = SafeStore(
        safeConfigManager: safeConfigManager,
        serverApiConnector: serverApiConnector,
        groupManager: businessInjector.groupManager,
        myIdentityStore: businessInjector.myIdentityStore,
        phoneNumberNormalizer: PhoneNumberNormalizer()
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
        super.init()

        router.delegate = self
        router.forwardDelegate = self
    }

    // MARK: - Presentation

    func start() {
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

    func finish() {
        router.unbind()
        cancellables.removeAll()
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    func show(_ destination: InternalDestination) {
        switch destination {
        case .editProfile:
            showEditProfile()

        case .scanQRCode:
            showScanner()

        case .qrCode:
            showQRCode()

        case .shareID:
            shareID(from: nil)

        case .workAvailabilityStatus:
            showWorkAvailabilityStatus()

        case .revocationPassword:
            showPasswordForRevocation()

        case .publicKey:
            showPublicKey()

        case .revokeDelete:
            showRevokeDelete()

        case .backups:
            // Already inside the authenticated backups area (backups itself or a
            // screen on top of it): navigate without asking for the passcode again.
            if path.first == .backups {
                setPath([.backups], animated: true)
                return
            }

            // Guard-then-mutate: the path only changes after authentication
            // succeeded, so cancelling requires no rollback.
            passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
                self?.setPath([.backups], animated: true)
            })

        case .threemaSafe:
            // Already shown: don't ask for the passcode again.
            guard path != [.backups, .threemaSafe] else {
                return
            }

            passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
                self?.setPath([.backups, .threemaSafe], animated: true)
            })

        case .linkPhone, .linkMail:
            setPath([destination], animated: true)
        }
    }

    func navigateToThreemaSafe() {
        show(.threemaSafe)
    }

    func dismiss() {
        presentingViewController?.presentedViewController?.dismiss(animated: true)
    }

    // MARK: - Router binding

    /// Hooks for `ThreemaSplitViewNavigationManager` to activate/deactivate this
    /// tab's router when tab selection or the size class changes.
    var routerHandle: RouterManagedTabHandle {
        RouterManagedTabHandle(
            deactivate: { [weak self] in
                self?.router.unbind()
            },
            activateCompact: { [weak self] in
                self?.bindCompact()
            },
            activateRegular: { [weak self] navigationController in
                self?.bindRegular(into: navigationController)
            },
            reauthenticateProtectedDestinations: { [weak self] in
                guard
                    let self,
                    path.first == .backups
                else {
                    return
                }
                // The backups area stays in place behind the prompt; cancelling
                // clears it. (With no passcode set this succeeds immediately.)
                passcodeRouter.requireAuthenticationIfNeeded(
                    onCancel: { [weak self] in
                        self?.setPath([], animated: false)
                    },
                    onSuccess: { }
                )
            },
            releaseMaterializedScreens: { [weak self] in
                guard
                    let self,
                    !router.isBound
                else {
                    return
                }
                router.releaseMaterializedScreens()
                // The tab's own navigation controller retains the compact stack
                // even while inactive — reset it to the root; the next
                // activation re-materializes the stack from the path.
                rootNavigationController.setViewControllers(
                    [profileViewController],
                    animated: false
                )
            }
        )
    }

    /// Collapsed width: the whole stack lives in the tab's own navigation
    /// controller, rooted in the profile screen.
    private func bindCompact() {
        router.bind(
            to: rootNavigationController,
            rootViewController: profileViewController
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// Regular width: the stack renders in the secondary column, rooted in a
    /// placeholder (the profile screen stays in the primary column). An empty path
    /// shows just the placeholder.
    private func bindRegular(into navigationController: UINavigationController) {
        router.bind(
            to: navigationController,
            rootViewController: ThreemaLogoViewController(rootView: ThreemaLogoView()),
            rootMode: .placeholder
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// While the collapse/expand transition that triggered a (re)bind is running,
    /// the size class still reports the old value and the appearance callbacks
    /// fired during it clear the list selection. Re-derive the selection once the
    /// transition has settled.
    private func scheduleSelectionSync() {
        DispatchQueue.main.async { [weak self] in
            self?.profileViewController.updateSelection()
        }
    }

    // MARK: - Screen construction

    private func makeScreen(_ destination: AnyHashable) -> UIViewController? {
        guard let destination = destination as? InternalDestination else {
            return nil
        }

        switch destination {
        case .backups:
            return makeBackupsScreen()

        case .threemaSafe:
            return makeThreemaSafeScreen()

        case .linkPhone:
            return UIHostingController(rootView: LinkPhoneNumberDeciderView())

        case .linkMail:
            return UIHostingController(rootView: LinkEmailDeciderView())

        case .editProfile, .scanQRCode, .qrCode, .shareID, .workAvailabilityStatus,
             .revocationPassword, .publicKey, .revokeDelete:
            // Actions and modals never materialize as path screens.
            return nil
        }
    }

    private func makeBackupsScreen() -> UIViewController? {
        guard let mdmSetup = MDMSetup() else {
            return nil
        }

        let model = BackupsViewModel(
            appFlavor: AppFlavorService(),
            mdmSetup: mdmSetup,
            safeManager: safeManager
        )

        let cancellable = model.routePublisher.sink { [weak self] route in
            switch route {
            case .threemaSafe:
                // Same guarded flow (skip when already shown, authenticate
                // otherwise) as entering Threema Safe from anywhere else.
                self?.show(.threemaSafe)
            case .idExport:
                self?.showPasswordForIDExport()
            }
        }
        cancellables.insert(cancellable)

        return UIHostingController(rootView: BackupsView(model: model))
    }

    private func makeThreemaSafeScreen() -> UIViewController? {
        guard let mdmSetup = MDMSetup() else {
            return nil
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

        return UIHostingController(rootView: ThreemaSafeDashboardView(model: model))
    }

    // MARK: - Private functions

    private var cancellables: Set<AnyCancellable> = []

    private func showEditProfile() {
        if businessInjector.userSettings.enableMultiDevice,
           businessInjector.serverConnector.connectionState != .loggedIn,
           let presentingViewController {
            UIAlertTemplate.showOKAlert(
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
                    audioSessionManager: BusinessInjector.ui.audioSessionManager,
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

                UIAlertTemplate.showOKAlert(
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

            // Push onto the scanner's modal navigation controller
            if let modalNavigationController =
                presentingViewController?.presentedViewController as? UINavigationController {
                modalNavigationController.pushViewController(viewController, animated: true)
            }
            else {
                modalRouter.present(viewController)
            }

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

    /// Presents the share-ID sheet. This is an action, not a destination:
    /// it does not change the navigation path.
    /// - Parameter sourceView: Popover anchor for regular size classes.
    func shareID(from sourceView: UIView?) {
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

    private func showWorkAvailabilityStatus() {
        let model = WorkAvailabilityStatusViewModel(profileStore: businessInjector.profileStore) { [weak self] in
            self?.dismiss()
        }

        let rootView = WorkAvailabilityStatusView(model: model)
        let vc = UIHostingController(rootView: rootView)
        modalRouter.present(vc)
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
                UIAlertTemplate.showOKAlert(
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
        
        guard deviceCapabilitiesManager.hasVideoCaptureDevice else {
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

// MARK: - PathCoordinator

extension ProfileCoordinator: PathCoordinator {

    /// Derived from the router — there is no separate state to keep in sync.
    var path: [InternalDestination] {
        router.path.compactMap { $0 as? InternalDestination }
    }

    func setPath(_ path: [InternalDestination], animated: Bool) {
        router.setPath(path.map { AnyHashable($0) }, animated: animated)
        profileViewController.updateSelection()
    }
}

// MARK: - NavigationRouterDelegate

extension ProfileCoordinator: NavigationRouterDelegate {

    /// The user popped (back button, swipe, tab re-tap pop-to-root): the path is
    /// already trimmed, only the list highlight needs a refresh.
    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable]) {
        profileViewController.updateSelection()
    }
}

// MARK: - UINavigationControllerDelegate

extension ProfileCoordinator: UINavigationControllerDelegate {

    /// Forwarded by the router (which owns the delegate slot while bound) to keep
    /// the status navigation bar content up to date.
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        (navigationController as? StatusNavigationController)?.updateNavigationBarContent()
    }
}

// MARK: - ProfileCollectionViewDataSource.Row

extension ProfileCollectionViewDataSource.Row {
    fileprivate func toProfileDestination() -> ProfileCoordinator.InternalDestination? {
        switch self {
        case .header:
            assertionFailure("Should not be possible to select.")
            return nil
        case .workAvailabilityStatus:
            return .workAvailabilityStatus
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
