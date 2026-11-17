import Foundation

/// Handles different media view controllers and switching between them.
/// Our media browser consists of two elements:
/// - A grid displaying images, videos and stickers
/// - A list displaying files and voice messages
///
/// The items in the list can also be displayed in full screen. This view can also be displayed directly when selecting
/// media in the chat view. File items just open the preview controller directly, like in chat view.
///
/// Create one per presentation and release it in `onDismiss`.
final class MediaBrowserCoordinator: NSObject, UINavigationControllerDelegate {
    
    // MARK: - Private properties
    
    private let conversationID: NSManagedObjectID
    private let entityManager: EntityManager
    private weak var presentationController: UIViewController?
    private let willDeleteMessages: ([NSManagedObjectID]) -> Void
    private let onDismiss: () -> Void
    
    // MARK: - Shared data

    private lazy var mediaManager = MediaBrowserMediaManager(
        conversationID: conversationID,
        entityManager: entityManager,
        willDeleteMessages: willDeleteMessages
    )

    // MARK: - ViewControllers

    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController(rootViewController: collectionViewController)
        navigationController.delegate = self
        return navigationController
    }()

    private lazy var collectionViewController = MediaBrowserCollectionViewController(
        mediaManager: mediaManager,
        onSelectMediaItem: { [weak self] objectID in
            self?.showPageViewController(for: objectID)
        },
        onClose: { [weak self] in
            self?.dismissBrowser()
        }
    )

    // MARK: - Lifecycle
    
    /// - Parameters:
    ///   - conversationID: Conversation to show the media of
    ///   - entityManager: Entity manager to fetch the media with
    ///   - willDeleteMessages: Called before messages are deleted, e.g. so an open chat does not show them anymore
    ///   - onDismiss: Called after the browser was dismissed. Release the coordinator here.
    init(
        conversationID: NSManagedObjectID,
        entityManager: EntityManager,
        willDeleteMessages: @escaping ([NSManagedObjectID]) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.conversationID = conversationID
        self.entityManager = entityManager
        self.willDeleteMessages = willDeleteMessages
        self.onDismiss = onDismiss

        super.init()
    }
    
    // MARK: - Public functions
    
    public func showGrid(on viewController: UIViewController) {
        viewController.present(navigationController, animated: true)
        presentationController = viewController
    }
    
    // MARK: - Private functions

    private func showPageViewController(for objectID: NSManagedObjectID) {
        // A new pager for each item opened, so its pages are released when going back
        let pageViewController = MediaBrowserPageViewController(
            mediaManager: mediaManager,
            objectID: objectID
        ) { [weak self] in
            self?.dismissBrowser()
        }
        navigationController.pushViewController(pageViewController, animated: true)
    }
    
    private func dismissBrowser() {
        guard let presentationController else {
            onDismiss()
            return
        }
        
        presentationController.dismiss(animated: true) { [weak self] in
            self?.onDismiss()
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        let isPush = operation == .push
        guard operation != .none,
              let pageViewController = (isPush ? toVC : fromVC) as? MediaBrowserPageViewController else {
            return nil
        }

        return MediaBrowserZoomTransition(
            isPush: isPush,
            gridViewController: collectionViewController,
            pageViewController: pageViewController
        )
    }
}
