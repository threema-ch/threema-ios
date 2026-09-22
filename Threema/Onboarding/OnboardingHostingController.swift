import SwiftUI
import UIKit

/// Hosts a SwiftUI screen inside the onboarding flow.
///
/// Adds what the storyboard based onboarding screens get for free: an opaque background and the swipe
/// gesture to go back to the previous screen.
final class OnboardingHostingController<Content: View>: UIHostingController<Content> {

    // MARK: - Private properties

    private let onSwipeBack: () -> Void

    // MARK: - Lifecycle

    init(rootView: Content, onSwipeBack: @escaping () -> Void) {
        self.onSwipeBack = onSwipeBack
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
        gestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(gestureRecognizer)
    }

    // MARK: - Actions

    @objc private func swipeAction(sender: UISwipeGestureRecognizer) {
        guard sender.state == .ended else {
            return
        }

        // The screen is on its way out, further swipes would navigate back a second time
        sender.isEnabled = false

        onSwipeBack()
    }
}
