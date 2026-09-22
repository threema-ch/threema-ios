import ThreemaFramework

struct NotificationManagerFactory: Factory {
    
    let businessInjector: any BusinessInjectorProtocol
    
    init(businessInjector: any BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    func make() -> NotificationManager {
        NotificationManager(businessInjector: businessInjector)
    }
}
