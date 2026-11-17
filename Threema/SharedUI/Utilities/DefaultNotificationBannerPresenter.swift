import ThreemaFramework
import UIKit

protocol NotificationBannerPresenting {
    func newBanner(on presentingViewController: UIViewController, baseMessage: BaseMessageEntity)
    /// Shows the banner about the reactions to a message of ours, replacing the one shown for it before
    func newReactionBanner(
        on presentingViewController: UIViewController,
        reactedMessage: BaseMessageEntity,
        body: String
    )
    func dismissAllNotifications(for identifier: String)
}

struct DefaultNotificationBannerPresenter: NotificationBannerPresenting {
    func newBanner(on presentingViewController: UIViewController, baseMessage: BaseMessageEntity) {
        NotificationBannerHelper.newBanner(on: presentingViewController, baseMessage: baseMessage)
    }

    func newReactionBanner(
        on presentingViewController: UIViewController,
        reactedMessage: BaseMessageEntity,
        body: String
    ) {
        NotificationBannerHelper.newBanner(
            on: presentingViewController,
            baseMessage: reactedMessage,
            reactionBody: body
        )
    }

    func dismissAllNotifications(for identifier: String) {
        NotificationBannerHelper.dismissAllNotifications(for: identifier)
    }
}
