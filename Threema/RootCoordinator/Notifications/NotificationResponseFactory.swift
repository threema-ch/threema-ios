import ThreemaFramework

struct NotificationResponseFactory {
    
    let businessInjector: any BusinessInjectorProtocol
    
    init(businessInjector: any BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    func make(
        notificationManager: NotificationManager,
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) -> NotificationResponse {
        NotificationResponse(
            businessInjector: businessInjector,
            notificationManager: notificationManager,
            response: response,
            completion: completionHandler
        )
    }
}
