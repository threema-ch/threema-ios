import CocoaLumberjackSwift
import UIKit

/// Handles interaction between gesture recognizer and navigation controller when swiping to cell details
final class ChatViewMessageRightToLeftTransitionProxy: NSObject {
    typealias Config = ChatViewConfiguration.ChatBubble.MessageDetailsInteraction
    
    // MARK: - Private Properties
    
    private weak var navigationController: UINavigationController?
    private weak var delegate: ChatViewTableViewCellDelegateProtocol?
    private var interactionController: UIPercentDrivenInteractiveTransition?
    
    // MARK: - Lifecycle
    
    init(delegate: ChatViewTableViewCellDelegateProtocol, navigationController: UINavigationController?) {
        self.navigationController = navigationController
        
        self.delegate = delegate
        
        super.init()
        
        navigationController?.delegate = self
    }
    
    // MARK: - Action Functions
    
    public func handleSwipeLeft(
        _ gestureRecognizer: UIPanGestureRecognizer,
        toViewController: UIViewController,
        onEnded: (() -> Void)? = nil
    ) {
        // Required for smooth animations when swiping to and from details.
        /// When swiping to details we want our handling, and when swiping back we want the default handling from
        /// navigationcontroller
        navigationController?.delegate = self
        defer { navigationController?.delegate = nil }
        
        var percent: CGFloat = 0
        if let view = gestureRecognizer.view {
            percent = -gestureRecognizer.translation(in: view).x / view.bounds.size.width
        }
        
        if gestureRecognizer.state == .began {
            interactionController = UIPercentDrivenInteractiveTransition()
            navigationController?.pushViewController(toViewController, animated: true)
        }
        else if gestureRecognizer.state == .changed {
            interactionController?.update(percent)
        }
        else if gestureRecognizer.state == .ended {
            if percent > Config.detailsCommitPercentage, gestureRecognizer.state != .cancelled {
                interactionController?.finish()
            }
            else {
                interactionController?.cancel()
            }
            onEnded?()
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension ChatViewMessageRightToLeftTransitionProxy: UINavigationControllerDelegate {
    // MARK: - UINavigationControllerDelegate Implementation

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push: return ChatViewMessageDetailsAnimationController(direction: .forward)
        case .pop:
            if toVC is ChatViewController {
                return ChatViewMessageDetailsAnimationController(direction: .backward)
            }
            return nil
        case .none: return nil
        @unknown default:
            let message =
                "Unknown switch case when handling animationControllerFor in ChatViewMessageRightToLeftTransitionProxy"
            DDLogError("\(message)")
            assertionFailure(message)
            return nil
        }
    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        interactionController
    }
}
