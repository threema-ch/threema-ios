import Intents
import UIKit

/// Long-lived proxy that forwards intent/URL/shortcut work to the real ``IntentHandler`` when
/// attached, and queues calls in receipt order until then.
///
/// All intent entry points arrive on the main actor via ``SceneDelegate``, so the proxy is plain
/// ``@MainActor`` with synchronous dispatch — no ``nonisolated``/``Task`` hops are needed.
@MainActor
final class IntentHandlerProxy: IntentHandling {

    private let dispatcher = DeferredDispatcher<IntentHandler>()

    func attach(_ handler: IntentHandler) {
        dispatcher.attach(handler)
    }

    func detach() {
        dispatcher.detach()
    }

    // MARK: - IntentHandling

    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool {
        dispatcher.dispatch {
            $0.handle(userActivity: userActivity)
        }
        return true
    }

    @discardableResult
    func handle(openURL url: URL) -> Bool {
        dispatcher.dispatch {
            $0.handle(openURL: url)
        }
        return true
    }

    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        dispatcher.dispatch {
            $0.handle(shortcutItem: shortcutItem)
        }
        return true
    }
}
