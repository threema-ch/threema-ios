import Coordinator
import Foundation
import ThreemaMacros

final class ConversationListCoordinator: Coordinator, CurrentDestinationHolderProtocol {
    
    // MARK: Internal destination
    
    enum InternalDestination: Equatable {
        case conversation(
            _: ConversationEntity,
            information: ShowConversationInformation? = nil
        )
        case archivedConversationList
        case archivedConversation(
            _: ConversationEntity,
            information: ShowConversationInformation? = nil
        )

        static func == (lhs: InternalDestination, rhs: InternalDestination) -> Bool {
            switch (lhs, rhs) {
            case let (.conversation(lhsConversation, _), .conversation(rhsConversation, _)):
                lhsConversation == rhsConversation
            case (.archivedConversationList, .archivedConversationList):
                true
            case let (.archivedConversation(lhsConversation, _), .archivedConversation(rhsConversation, _)):
                lhsConversation == rhsConversation
            default:
                false
            }
        }
    }
    
    // MARK: - Coordinator
    
    var childCoordinators = [any Coordinator]()
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    var currentDestination: InternalDestination?
    
    private lazy var conversationListViewController: ConversationListViewController = {
        let conversationListViewController = ConversationListViewController(
            delegate: self,
            isRegularSizeClass: { [weak self] in
                self?.presentingViewController?.isCollapsed == false
            }()
        )
        
        let tab = ThreemaTab(.conversations)
        conversationListViewController.tabBarItem = tab.tabBarItem
        conversationListViewController.title = tab.title
        
        return conversationListViewController
    }()
    
    private var archivedConversationListViewController: ArchivedConversationListViewController? {
        rootNavigationController.topViewController as? ArchivedConversationListViewController
    }
    
    private lazy var rootNavigationController = StatusNavigationController()
        
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: conversationListViewController,
        splitViewController: presentingViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    private weak var presentingViewController: ThreemaSplitViewController?
    private let viewControllerForDestination: (InternalDestination) -> UIViewController
    private let isPasscodeRequired: () -> Bool
    private lazy var passcodeRouter: any PasscodeRouterProtocol = PasscodeRouter(
        lockScreen: LockScreen(isLockScreenController: false),
        isPasscodeRequired: { [weak self] in
            self?.isPasscodeRequired() == true
        }(),
        rootViewController: { [weak self] in
            guard let viewController = self?.presentingViewController?.viewControllers.last else {
                fatalError("ThreemaSplitViewController is missing a view controller.")
            }
            
            return viewController
        }()
    )
    
    var selectedConversation: ConversationEntity? {
        conversationListViewController.selectedConversation
    }
    
    private var secondaryViewController: UIViewController? {
        guard presentingViewController?.isCollapsed == false else {
            return nil
        }
        
        return presentingViewController?
            .navigationController(for: .conversations)
            .flatMap(\.topViewController)
    }
    
    init(
        presentingViewController: ThreemaSplitViewController,
        viewControllerForDestination: @escaping (InternalDestination) -> UIViewController,
        isPasscodeRequired: @autoclosure @escaping () -> Bool
    ) {
        self.presentingViewController = presentingViewController
        self.viewControllerForDestination = viewControllerForDestination
        self.isPasscodeRequired = isPasscodeRequired
    }
    
    // MARK: - Presentation
    
    func start() {
        rootNavigationController.delegate = navigationDestinationResetter
        
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [conversationListViewController],
            animated: false
        )
    }
    
    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }
        
        resetSelection()
        currentDestination = destination
    
        let viewController = viewControllerForDestination(destination)
        
        switch viewController {
        case let chatViewController as ChatViewController:
            showChatViewController(chatViewController, animated: true)
            
        case let archivedListViewController as ArchivedConversationListViewController:
            rootNavigationController.pushViewController(
                archivedListViewController,
                animated: true
            )
            
        default:
            return
        }
    }
    
    func resetSelection() {
        resetCurrentDestination()
        conversationListViewController.removeSelectedConversation()
        presentingViewController?.setViewControllers([], for: .conversations)
    }
    
    private func dismissPasscodeIfNeeded() {
        guard
            presentingViewController?.isCollapsed == false,
            selectedConversation?.conversationCategory == .private
        else {
            return
        }
        
        passcodeRouter.rootViewController().presentedViewController?
            .dismiss(animated: false)
        resetSelection()
    }
    
    @objc private func showChatViewController(
        _ chatViewController: ChatViewController,
        animated: Bool
    ) {
        /// Due to the navigationController being able to change upon resizing,
        /// we need to get the correct instance when using it.
        let navigationController = { [weak self] in
            self?.presentingViewController?.switchTabIfNeeded(to: .conversations)
            return self?.presentingViewController?.navigationController(
                for: .conversations
            )
        }
        
        /// Chat is already displayed
        guard navigationController()?.topViewController != chatViewController else {
            return
        }
        
        /// In the view hierarchy, there is already a view for the chat, pop stack view controller to it
        guard navigationController()?.viewControllers.contains(chatViewController) == false else {
            guard navigationController()?.topViewController?.presentedViewController == nil else {
                return
            }
            
            navigationController()?.popToViewController(chatViewController, animated: animated)
            return
        }
        
        handlePresentation(of: chatViewController)
        
        handleConversationSelection(for: chatViewController)
    }
    
    private func handleConversationSelection(for chatViewController: ChatViewController) {
        guard presentingViewController?.isCollapsed == false else {
            return
        }
        
        conversationListViewController.selectionManager.allowSelectionSetting = true
        conversationListViewController.setSelection(for: chatViewController.conversation)
        
        guard let archivedConversationListViewController else {
            return
        }
        
        archivedConversationListViewController.setSelection(for: chatViewController.conversation)
    }
    
    private func handlePresentation(of chatViewController: ChatViewController) {
        if chatViewController.conversation.conversationCategory == .private {
            /// If we restored from safe and no password is set, we inform the user that he needs to set one and present
            /// them the set password screen
            if isPasscodeRequired() == false {
                UIAlertTemplate.showAlert(
                    owner: rootNavigationController,
                    title: #localize("privateChat_alert_title"),
                    message: String.localizedStringWithFormat(
                        #localize("privateChat_setup_alert_message"),
                        TargetManager.localizedAppName
                    ),
                    titleOk: #localize("privateChat_code_alert_confirm"),
                    actionOk: { [weak self, chatViewController] _ in
                        self?.presentChatViewControllerAfterPasscode(chatViewController)
                    }
                )
            }
            else {
                presentChatViewControllerAfterPasscode(chatViewController)
            }
        }
        else {
            present(chatViewController)
        }
    }
    
    private func present(_ chatViewController: ChatViewController) {
        let navigationController = rootNavigationController
        let isCollapsed = presentingViewController?.isCollapsed
        
        if isCollapsed == true {
            let archivedListViewController =
                rootNavigationController.viewControllers.first {
                    $0 is ArchivedConversationListViewController
                }

            /// Save destination before popping — the
            /// `NavigationDestinationResetter` fires during
            /// `popToRootViewController` and clears `currentDestination`.
            let savedDestination = currentDestination
            navigationController.popToRootViewController(animated: false)
            currentDestination = savedDestination

            var viewControllers: [UIViewController] = [chatViewController]

            if case .archivedConversation = currentDestination,
               archivedListViewController == nil {
                let viewController = viewControllerForDestination(.archivedConversationList)
                viewControllers.insert(viewController, at: 0)
            }
            else if case .conversation = currentDestination,
                    let archivedListViewController {
                viewControllers.insert(archivedListViewController, at: 0)
            }

            viewControllers.insert(conversationListViewController, at: 0)

            navigationController.setViewControllers(viewControllers, animated: true)
        }
        else {
            handleRootNavigationController()
            
            /// In case the passcode is presented from a private chat
            passcodeRouter.rootViewController().dismiss(animated: false)
            
            presentingViewController?.show(chatViewController, sender: self)
        }
    }
    
    private func handleRootNavigationController() {
        let archivedListViewController =
            rootNavigationController.viewControllers.last as? ArchivedConversationListViewController
        
        switch currentDestination {
        case let .conversation(conversation, _):
            guard archivedListViewController != nil else {
                return
            }
            
            conversationListViewController.setSelection(for: conversation)
            rootNavigationController.popToRootViewController(animated: true)
            
        case let .archivedConversation(conversation, _):
            guard archivedListViewController == nil,
                  let viewController = viewControllerForDestination(
                      .archivedConversationList
                  ) as? ArchivedConversationListViewController else {
                return
            }
            
            viewController.setSelection(for: conversation)
            rootNavigationController.pushViewController(viewController, animated: true)
            conversationListViewController.removeSelectedConversation()
            
        default:
            return
        }
    }
    
    private func presentChatViewControllerAfterPasscode(_ chatViewController: ChatViewController) {
        passcodeRouter.requireAuthenticationIfNeeded(
            style: .currentContext,
            onCancel: { [weak self] in
                self?.resetCurrentDestination()
                
                self?.conversationListViewController.removeSelectedConversation()
                self?.conversationListViewController.setSelection(for: nil)
                
                if let viewController = self?.rootNavigationController.viewControllers.first(where: {
                    $0 is ArchivedConversationListViewController
                }) as? ArchivedConversationListViewController {
                    viewController.removeSelectedConversation()
                    viewController.setSelection(for: nil)
                }
            },
            onSuccess: { [weak self, chatViewController] in
                self?.present(chatViewController)
            }
        )
    }
}

// MARK: - ConversationListViewControllerDelegate

extension ConversationListCoordinator: ConversationListViewControllerDelegate {
    func didSelectConversation(conversation: ConversationEntity) {
        let destination: InternalDestination = conversation.conversationVisibility == .archived
            ? .archivedConversation(conversation)
            : .conversation(conversation)
        
        if conversation.conversationVisibility == .archived {
            conversationListViewController.selectionManager.removeSelection()
        }
        
        show(destination)
    }
    
    func archivedConversationListTriggered() {
        show(.archivedConversationList)
    }
    
    func willDisappear() {
        dismissPasscodeIfNeeded()
    }
}
