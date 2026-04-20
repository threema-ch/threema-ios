import Foundation

/// Extension to create own static notification names
extension Notification.Name {
    public static let identityLinkedWithMobileNo = Notification.Name("ThreemaIdentityLinkedWithMobileNo")
    public static let navigateSafeSetup = Notification.Name(kNotificationShowSafeSetup)
    public static let incomingProfileSync = Notification.Name(kNotificationIncomingProfileSynchronization)
    public static let showDesktopSettings = Notification.Name("ThreemaShowDesktopSettings")
    public static let serverMessage = Notification.Name(kNotificationServerMessage)
    public static let errorConnectionFailed = Notification.Name(kNotificationErrorConnectionFailed)
    public static let errorPublicKeyMismatch = Notification.Name(kNotificationErrorPublicKeyMismatch)
    public static let errorRogueDevice = Notification.Name(kNotificationErrorRogueDevice)
    public static let resetSSLCAHelperCache = Notification.Name("ThreemaResetSSLCAHelperCache")
    public static let backupInProgressStatus = Notification.Name("ThreemaBackupInProgressStatus")
    public static let profileUIRefresh = Notification.Name("ThreemaProfileUIRefresh")
}
