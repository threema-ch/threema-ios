import CocoaLumberjackSwift
import Coordinator
import DataBackup
import FileUtility
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class SettingsCoordinator: NSObject, Coordinator {

    // MARK: - Internal destination

    enum InternalDestination: Hashable {

        enum BackupsDestination: Hashable {
            case center
            case recoveryKey
            case recoveryKeyConfirmation
            case settings
            case creation
            case details
            case threemaSafeDashboard
        }

        case betaFeedback
        case developer
        
        case coordinatorDemo

        case privacy
        case appearance
        case notifications
        case chat
        case media

        case backups(BackupsDestination)

        case storage
        case passcode
        case calls

        case desktop
        case web

        case invite
        case channel
        case workInfo
        case workReferral

        case support
        case policy
        case tos
        case license
        case advanced
    }

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }

    // MARK: - Routers

    private let shareActivityRouter: any ShareActivityRouterProtocol
    private let passcodeRouter: any PasscodeRouterProtocol
    private let router = NavigationRouter()

    /// The surface child coordinators use to contribute screens to this tab's
    /// shared path (see the `.coordinatorDemo` flow). A thin adapter over the
    /// router — children never see this coordinator directly.
    private lazy var pathHost: any PathHost = RouterPathHost(router: router)

    // MARK: - Private properties

    private lazy var settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
    private lazy var screenFactory = SettingsScreenFactory(settingsStore: settingsStore, coordinator: self)

    private(set) weak var presentingViewController: ThreemaSplitViewController?

    private lazy var settingsViewController: SettingsViewController = {
        let settingsViewController = SettingsViewController(coordinator: self)

        let tab = ThreemaTab(.settings)
        settingsViewController.tabBarItem = tab.tabBarItem
        settingsViewController.title = tab.title

        return settingsViewController
    }()

    private lazy var rootNavigationController = StatusNavigationController()

    // MARK: - Lifecycle

    init(
        presentingViewController: ThreemaSplitViewController,
        shareActivityRouter: any ShareActivityRouterProtocol,
        passcodeRouter: any PasscodeRouterProtocol
    ) {
        self.presentingViewController = presentingViewController
        self.shareActivityRouter = shareActivityRouter
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
            [settingsViewController],
            animated: false
        )
    }

    func finish() {
        router.unbind()
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    /// Entry point for the settings list. Actions (chats, share sheets) are
    /// performed directly; destinations replace the navigation path.
    func show(_ destination: InternalDestination, animated: Bool = true) {
        switch destination {
        case .betaFeedback:
            openBetaFeedbackChat()

        case .channel:
            openChannelChat()

        case .invite:
            showInviteActivity(from: nil)

        case .coordinatorDemo:
            startCoordinatorDemo()

        case .passcode:
            // Already shown: don't ask for the passcode again.
            guard path != [.passcode] else {
                return
            }

            // Guard-then-mutate: the path only changes after authentication
            // succeeded, so cancelling requires no rollback.
            passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
                self?.setPath([.passcode], animated: animated)
            })

        case let .backups(destination):
            handleBackupsDestination(destination, animated: animated)

        default:
            setPath([destination], animated: animated)
        }
    }

    // MARK: - Child coordinator flow (example)

    private func startCoordinatorDemo() {
        for case let demo as DemoFlowCoordinator in childCoordinators {
            demo.finish()
        }
        childCoordinators.removeAll { $0 is DemoFlowCoordinator }

        let demo = DemoFlowCoordinator(host: pathHost)
        childCoordinators.append(demo)
        demo.start()
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
                    path.contains(.passcode)
                else {
                    return
                }
                // The passcode settings stay in place behind the prompt;
                // cancelling clears them. (With no passcode set this succeeds
                // immediately.)
                passcodeRouter.requireAuthenticationIfNeeded(
                    onCancel: { [weak self] in
                        guard let self else {
                            return
                        }
                        setPath(path.filter { $0 != .passcode }, animated: false)
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
                    [settingsViewController],
                    animated: false
                )
            }
        )
    }

    /// Collapsed width: the whole stack lives in the tab's own navigation
    /// controller, rooted in the settings list.
    private func bindCompact() {
        router.bind(
            to: rootNavigationController,
            rootViewController: settingsViewController
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// Regular width: the stack renders in the secondary column, rooted in a
    /// placeholder (the settings list stays in the primary column). An empty path
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
            self?.settingsViewController.updateSelection()
        }
    }

    private func makeScreen(_ destination: AnyHashable) -> UIViewController? {
        guard let destination = destination as? InternalDestination else {
            return nil
        }
        return screenFactory.make(destination)
    }

    private func handleBackupsDestination(_ destination: InternalDestination.BackupsDestination, animated: Bool = true) {
        switch destination {
        case .center:
            passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
                self?.setPath([.backups(.center)], animated: animated)
            })

        case .recoveryKey:
            setPath(path + [.backups(.recoveryKey)], animated: animated)

        case .recoveryKeyConfirmation:
            setPath(path + [.backups(.recoveryKeyConfirmation)], animated: animated)

        case .settings:
            setPath(path + [.backups(.settings)], animated: animated)

        case .creation:
            setPath([.backups(.center), .backups(.creation)], animated: animated)

        case .details:
            setPath([.backups(.center), .backups(.details)], animated: animated)

        case .threemaSafeDashboard:
            setPath(path + [.backups(.threemaSafeDashboard)], animated: animated)
        }
    }

    // MARK: - Actions

    private func openBetaFeedbackChat() {
        let versionText = "Version: \(ThreemaUtility.clientVersionWithMDM)"
        if let contact = BusinessInjector.ui.entityManager.entityFetcher
            .contactEntity(for: Constants.betaFeedbackIdentity) {
            showConversation(for: contact, text: versionText)
        }
        else {
            BusinessInjector.ui.contactStore.addContact(
                with: Constants.betaFeedbackIdentity,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue)
            ) { contact, _ in
                guard let contactEntity = contact as? ContactEntity else {
                    DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact")
                    return
                }

                self.showConversation(for: contactEntity, text: versionText)
            } onError: { error in
                DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact \(error)")
            }
        }
    }

    /// Presents the invite share sheet. This is an action, not a destination:
    /// it does not change the navigation path.
    /// - Parameter sourceView: Popover anchor for regular size classes.
    func showInviteActivity(from sourceView: UIView?) {
        let shareText = String.localizedStringWithFormat(
            #localize("invite_sms_body"),
            TargetManager.appName,
            TargetManager.localizedAppName,
            BusinessInjector.ui.myIdentityStore.identity ?? ""
        )
        shareActivityRouter.present(items: [shareText], sourceView: sourceView)
    }

    private func openChannelChat() {
        guard TargetManager.isPrivate || TargetManager.isWork else {
            return
        }

        let identity = TargetManager.isPrivate ? PredefinedContacts.threema.identity : PredefinedContacts.threemaWork.identity

        guard let identity else {
            return
        }
        let businessInjector = BusinessInjector.ui
        let entityManager = businessInjector.entityManager
        let contactEntity = entityManager.performAndWait {
            entityManager.entityFetcher.contactEntity(for: identity.rawValue)
        }

        if let contactEntity {
            showConversation(for: contactEntity)
            return
        }

        let title = TargetManager.isPrivate ? #localize("threema_channel_intro") : #localize(
            "threema_work_channel_intro"
        )
        let message = TargetManager.isPrivate ? #localize("threema_channel_info") : #localize(
            "threema_work_channel_info"
        )

        UIAlertTemplate.showAlert(
            owner: rootViewController,
            title: title,
            message: message,
            titleOk: #localize("add_button"),
            actionOk: { _ in
                addChannel(in: self.rootViewController, identity: identity.rawValue)
            }
        )

        func addChannel(in viewController: UIViewController, identity: String) {
            ContactStore.shared().addContact(
                with: identity,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue),
                onCompletion: { contact, _ in
                    guard let contactEntity = contact as? ContactEntity else {
                        let title = TargetManager.isPrivate ? #localize("threema_channel_failed") : #localize(
                            "threema_work_channel_failed"
                        )
                        UIAlertTemplate.showOKAlert(
                            owner: viewController,
                            title: title,
                            message: nil
                        )
                        return
                    }

                    self.showConversation(for: contactEntity)

                    let initialMessages = createInitialMessages()
                    dispatchInitialMessages(messages: initialMessages, with: contactEntity)

                }, onError: { error in
                    let title = TargetManager.isPrivate ? #localize("threema_channel_failed") : #localize(
                        "threema_work_channel_failed"
                    )
                    UIAlertTemplate.showOKAlert(
                        owner: viewController,
                        title: title,
                        message: error.localizedDescription
                    )
                }
            )
        }

        func createInitialMessages() -> [String] {
            var initialMessages = [String]()

            if !(Bundle.main.preferredLocalizations[0].hasPrefix("de")) {
                initialMessages.append("en")
            }
            else {
                initialMessages.append("de")
            }

            if TargetManager.isPrivate {
                initialMessages.append("Start News")
            }
            initialMessages.append("Start iOS")
            initialMessages.append("Info")

            return initialMessages
        }

        func dispatchInitialMessages(messages: [String], with contact: ContactEntity) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                let businessInjector = BusinessInjector.ui

                guard let conversation = businessInjector.entityManager.entityFetcher
                    .conversationEntity(for: contact.identity) else {
                    DDLogWarn("Unable to add initial messages to Threema Channel. Reason: conversation not found.")
                    return
                }

                for (index, message) in messages.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index)) {
                        businessInjector.messageSender.sendTextMessage(
                            containing: message,
                            in: conversation
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper functions

    private func showConversation(for contact: ContactEntity, text: String? = nil) {
        var info = [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(booleanLiteral: text != nil),
        ] as [String: Any]

        if let text {
            info[kKeyText] = text
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
}

// MARK: - PathCoordinator

extension SettingsCoordinator: PathCoordinator {

    /// Derived from the router — there is no separate state to keep in sync.
    var path: [InternalDestination] {
        router.path.compactMap { $0 as? InternalDestination }
    }

    func setPath(_ path: [InternalDestination], animated: Bool) {
        router.setPath(path.map { AnyHashable($0) }, animated: animated)
        settingsViewController.updateSelection()
    }
}

// MARK: - NavigationRouterDelegate

extension SettingsCoordinator: NavigationRouterDelegate {

    /// The user popped (back button, swipe, tab re-tap pop-to-root): the path is
    /// already trimmed, only the list highlight needs a refresh.
    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable]) {
        settingsViewController.updateSelection()
    }
}

// MARK: - UINavigationControllerDelegate

extension SettingsCoordinator: UINavigationControllerDelegate {

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
