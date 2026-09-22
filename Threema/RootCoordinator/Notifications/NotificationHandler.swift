import Foundation
import PushKit
import ThreemaFramework
import UserNotifications

final class NotificationHandler: NSObject,
    UNUserNotificationCenterDelegate,
    PKPushRegistryDelegate {

    private let notificationManager: NotificationManager
    private let notificationResponseFactory: NotificationResponseFactory
    private let serverConnector: any ServerConnectorProtocol
    private let isAppActive: () -> Bool
    private let showNotificationSettings: () -> Void

    init(
        notificationManager: NotificationManager,
        notificationResponseFactory: NotificationResponseFactory,
        serverConnector: any ServerConnectorProtocol,
        isAppActive: @escaping () -> Bool,
        showNotificationSettings: @escaping () -> Void
    ) {
        self.notificationManager = notificationManager
        self.notificationResponseFactory = notificationResponseFactory
        self.serverConnector = serverConnector
        self.isAppActive = isAppActive
        self.showNotificationSettings = showNotificationSettings
        super.init()
    }

    // MARK: - PKPushRegistryDelegate

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else {
            DDLogNotice("Push type is not VoIP (\(type))")
            return
        }

        serverConnector.removeVoIPPushToken()

        guard !credentials.token.isEmpty else {
            DDLogNotice("VoIP token is null")
            return
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if !isAppActive() {
            DDLogNotice("[Push] willPresentNotification: Start NotificationExtension for received push")
            // Do not handle notifications if the app is not active -> Show notification in iOS, not in the app
            completionHandler([.list, .banner, .badge, .sound])
        }
        else {
            DDLogNotice("[Push] willPresentNotification: Handle notification for received push")

            notificationManager.handleThreemaNotification(
                payload: notification.request.content.userInfo,
                receivedWhileRunning: true,
                notification: notification,
                withCompletionHandler: completionHandler
            )
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let wrapped = notificationResponseFactory.make(
            notificationManager: notificationManager,
            response: response,
            completionHandler: completionHandler
        )
        wrapped.handleNotificationResponse()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        showNotificationSettings()
    }

    func resetFirstPushHandled() {
        notificationManager.firstPushHandled = false
    }
}
