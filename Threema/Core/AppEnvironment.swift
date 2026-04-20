import ThreemaFramework

public struct AppEnvironment {
    @NotificationPublisher(Notification.Name(kNotificationColorThemeChanged))
    var colorChanged
    
    @NotificationPublisher(Notification.Name(kShowNotificationSettings))
    var showNotificationSettings
    
    @NotificationPublisher(.showDesktopSettings)
    var showDesktopSettings
    
    @NotificationPublisher(Notification.Name(kNotificationSettingStoreSynchronization))
    var mdmChanged
    
    @NotificationPublisher(.navigateSafeSetup)
    var showSafeSetup
    
    @NotificationPublisher(.incomingProfileSync)
    var profileSyncPublisher
    
    @NotificationPublisher(.identityLinkedWithMobileNo)
    var identityLinked
    
    @NotificationPublisher(UIApplication.willEnterForegroundNotification)
    var enteredForeground
    
    @NotificationPublishedState(Notification.Name(kNotificationNavigationBarColorShouldChange))
    var notificationBarColorShouldChange
    
    @NotificationPublishedState(Notification.Name(kNotificationNavigationItemPromptShouldChange))
    var notificationBarItemPromptShouldChange
    
    var businessInjector: BusinessInjectorProtocol
}
