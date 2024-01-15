//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

        let initialX: CGFloat
        switch direction {
        case .forward: initialX = fromView.bounds.width
        case .backward: initialX = -fromView.bounds.width
        }
        
        toView.frame = CGRect(origin: CGPoint(x: initialX, y: 0), size: toView.bounds.size)

        let animation: () -> Void = {
            toView.frame = CGRect(origin: .zero, size: toView.bounds.size)
        }
        
        let completion: (Bool) -> Void = { _ in
            let success = !transitionContext.transitionWasCancelled
            if !success {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(success)
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
