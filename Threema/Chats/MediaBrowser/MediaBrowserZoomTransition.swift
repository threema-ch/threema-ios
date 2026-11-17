import AVFoundation
import UIKit

/// Zooms the thumbnail of an item between its grid cell and the pager
///
/// The system zoom transition does not work in a sheet, so we animate a snapshot of the thumbnail ourselves.
final class MediaBrowserZoomTransition: NSObject, UIViewControllerAnimatedTransitioning {

    private enum Configuration {
        static let duration: TimeInterval = 0.35
        static let dampingRatio: CGFloat = 0.9
    }

    private let isPush: Bool
    private let gridViewController: MediaBrowserCollectionViewController
    private let pageViewController: MediaBrowserPageViewController

    init(
        isPush: Bool,
        gridViewController: MediaBrowserCollectionViewController,
        pageViewController: MediaBrowserPageViewController
    ) {
        self.isPush = isPush
        self.gridViewController = gridViewController
        self.pageViewController = pageViewController
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        Configuration.duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let pageView: UIView = pageViewController.view
        let gridView: UIView = gridViewController.view

        // The pager is always on top of the grid
        if isPush {
            pageView.frame = transitionContext.finalFrame(for: pageViewController)
            containerView.addSubview(pageView)
        }
        else {
            gridView.frame = transitionContext.finalFrame(for: gridViewController)
            containerView.insertSubview(gridView, belowSubview: pageView)
        }
        pageView.layoutIfNeeded()
        gridView.layoutIfNeeded()

        let cell = pageViewController.shownObjectID.flatMap { gridViewController.zoomSourceCell(for: $0) }
        let snapshot = cell.flatMap { makeSnapshot(of: $0, in: containerView) }

        let cellFrame = cell.map { $0.convert($0.bounds, to: containerView) } ?? .zero
        let pageFrame = snapshot?.image.map { image in
            AVMakeRect(
                aspectRatio: image.size,
                insideRect: pageView.convert(pageViewController.mediaFrame, to: containerView)
            )
        } ?? .zero

        snapshot?.frame = isPush ? cellFrame : pageFrame
        pageView.alpha = isPush ? 0 : 1
        cell?.isHidden = true
        pageViewController.isMediaHidden = true

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            dampingRatio: Configuration.dampingRatio
        ) {
            snapshot?.frame = self.isPush ? pageFrame : cellFrame
            pageView.alpha = self.isPush ? 1 : 0
        }

        animator.addCompletion { _ in
            snapshot?.removeFromSuperview()
            cell?.isHidden = false
            pageView.alpha = 1
            self.pageViewController.isMediaHidden = false

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.startAnimation()
    }

    private func makeSnapshot(
        of cell: MediaBrowserGridCollectionViewCell,
        in containerView: UIView
    ) -> UIImageView? {
        guard let image = cell.thumbnailImage else {
            return nil
        }

        // Aspect fill turns the square crop of the cell smoothly into the whole image
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)
        return imageView
    }
}
