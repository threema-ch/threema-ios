import UIKit

/// Implements UIViewControllerAnimatedTransitioning to allow the DetailsViewController to appear with a percentage
/// driven animation when swiping on the cells
final class ChatViewMessageDetailsAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    typealias Config = ChatViewConfiguration.ChatBubble.MessageDetailsInteraction
    
    // MARK: - Nested Types
    
    enum Direction {
        case forward, backward
    }
    
    // MARK: - Private Properties
    
    private let direction: Direction

    // MARK: - Lifecycle
    
    init(direction: Direction) {
        self.direction = direction
    }
    
    // MARK: Action Functions

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to),
              let fromView = transitionContext.view(forKey: .from) else {
            return
        }

        let container = transitionContext.containerView
        container.addSubview(toView)

        let initialX: CGFloat =
            switch direction {
            case .forward: fromView.bounds.width
            case .backward: -fromView.bounds.width
            }
        
        toView.frame = CGRect(origin: CGPoint(x: initialX, y: 0), size: toView.bounds.size)

        let animation: () -> Void = {
            toView.frame = CGRect(origin: .zero, size: toView.bounds.size)
            
            // Fixes an issue in iOS 26, where text in chat bubbles would be in the wrong place after showing message
            // details.
            if #available(iOS 26.0, *) {
                UIView.setAnimationsEnabled(false)
            }
        }
        
        let completion: (Bool) -> Void = { _ in
            let success = !transitionContext.transitionWasCancelled
            if !success {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(success)
            // Fixes an issue in iOS 26, where text in chat bubbles would be in the wrong place after showing message
            // details.
            if #available(iOS 26.0, *) {
                UIView.setAnimationsEnabled(true)
            }
        }
        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            animations: animation,
            completion: completion
        )
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        Config.transitionDuration
    }
}
