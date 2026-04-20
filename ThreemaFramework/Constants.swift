import ContactsUI
import Foundation

/// Complicated constants that cannot easily be imported form Objective-C redefined for Swift
///
/// For example non-trivial macros cannot be imported:
/// <https://developer.apple.com/videos/play/wwdc2020/10680/?time=1801>
///
/// When you add a new constant use the same name but remove the `k`. Add a comment with the name of the corresponding
/// Objective-C constant.
public enum Constants {
    
    /// Contact keys to fetch from `CNContactStore`
    ///
    /// - SeeAlso: kCNContactKeys
    public static let cnContactKeys = [
        CNContactFamilyNameKey,
        CNContactGivenNameKey,
        CNContactMiddleNameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactImageDataKey,
        CNContactImageDataAvailableKey,
        CNContactThumbnailImageDataKey,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactViewController.descriptorForRequiredKeys(),
    ] as! [CNKeyDescriptor]
    
    /// Beta feedback identity
    public static let betaFeedbackIdentity = "*BETAFBK"
    
    /// Showed notification type selection view
    public static let showedNotificationTypeSelectionView = "showedNotificationTypeSelectionView"
    /// Key for all custom wallpaper
    public static let wallpaperKey = "Wallpapers"
    
    /// Key for app setup state setting
    ///
    /// - SeeAlso: kAppSetupStateKey
    public static let appSetupStateKey = kAppSetupStateKey
    
    public static let messageStoringGatewayGroupPrefix = "☁"
    
    // Keys to transfer call info from NSE to app
    public static let notificationExtensionOffer = "NotificationExtensionOffer"
    public static let notificationExtensionCallerName = "NotificationExtensionCallerName"
    public static let notificationExtensionRingtoneSoundName = "NotificationExtensionRingtoneSoundName"
    public static let notificationExtensionCallID = "NotificationExtensionCallID"
}

extension String {
    public static var broadcasts: String { "*" }
}
