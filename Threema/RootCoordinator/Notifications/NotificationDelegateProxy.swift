import Foundation
import PushKit
import UserNotifications

/// Receiver that the proxy forwards user notification and VoIP credential callbacks to. In
/// production this is the real ``NotificationHandler``.
typealias NotificationDelegating = UNUserNotificationCenterDelegate & PKPushRegistryDelegate

/// Long-lived proxy to be used as the `UNUserNotificationCenter` and `PKPushRegistry` delegate at
/// `application(_:didFinishLaunchingWithOptions:)` time. Early enough to satisfy Apple's contract
/// that the delegate be assigned before the system delivers callbacks.
///
/// Callbacks arriving before the real ``NotificationHandler`` is constructed (i.e. before the
/// launch sequence finishes building `BusinessInjector`) are queued and replayed in receipt order
/// once ``attach(_:)`` is invoked. Preserves the legacy `runWhenBusinessReady` semantics without
/// leaking optional state into `NotificationHandler`.
///
/// Incoming VoIP pushes are the one exception: they are never queued. PushKit terminates the app if
/// no call is reported to CallKit before its delegate callback returns, so they go straight to
/// ``VoIPPushHandler``, which needs nothing but the payload. See there for details.
///
/// MainActor-isolated because both `UNUserNotificationCenter` and the `PKPushRegistry` constructed
/// with the main dispatch queue deliver their callbacks on main. Matches delivery thread; no
/// extra hops on the VoIP push path.
@MainActor
final class NotificationDelegateProxy: NSObject,
    UNUserNotificationCenterDelegate,
    PKPushRegistryDelegate {

    /// Held only to keep the registry created in `ApplicationDelegate` alive
    private let pushRegistry: PKPushRegistry
    private let dispatcher = DeferredDispatcher<NotificationDelegating>()
    private let voIPPushHandler = VoIPPushHandler()

    init(pushRegistry: PKPushRegistry) {
        self.pushRegistry = pushRegistry
        super.init()
    }

    /// Install the real handler. Any callbacks captured before this point are forwarded in receipt
    /// order. Calling twice replaces the target; pending queue is drained against the new target.
    func attach(_ handler: NotificationDelegating) {
        voIPPushHandler.businessDidBecomeReady()
        dispatcher.attach(handler)
    }

    func detach() {
        dispatcher.detach()
    }

    func businessDidBecomeReady() {
        voIPPushHandler.businessDidBecomeReady()
    }

    // MARK: - PKPushRegistryDelegate

    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        Task { @MainActor [weak self] in
            self?.dispatcher.dispatch { handler in
                handler.pushRegistry(registry, didUpdate: credentials, for: type)
            }
        }
    }

    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        MainActor.assumeIsolated { [weak self] in
            guard let self else {
                completion()
                return
            }

            voIPPushHandler.report(dictionaryPayload: payload.dictionaryPayload, completion: completion)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.dispatcher.dispatch { handler in
                handler.userNotificationCenter?(
                    center,
                    willPresent: notification,
                    withCompletionHandler: completionHandler
                )
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.dispatcher.dispatch { handler in
                handler.userNotificationCenter?(
                    center,
                    didReceive: response,
                    withCompletionHandler: completionHandler
                )
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        Task { @MainActor [weak self] in
            self?.dispatcher.dispatch { handler in
                handler.userNotificationCenter?(center, openSettingsFor: notification)
            }
        }
    }
}
