import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` (the UserNotifications framework's shared center)
/// so its use can be injected and mocked. This is deliberately separate from
/// `NotificationCenterProtocol`, which abstracts Foundation's `NotificationCenter` and shares no
/// API with `UNUserNotificationCenter`.
///
/// Only the methods currently needed are declared; grow this method-by-method as call sites migrate.
public protocol UserNotificationCenterProtocol {
    func removeAllDeliveredNotifications()

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping (Bool, (any Error)?) -> Void
    )
}

// MARK: - UNUserNotificationCenter + UserNotificationCenterProtocol

extension UNUserNotificationCenter: UserNotificationCenterProtocol { }
