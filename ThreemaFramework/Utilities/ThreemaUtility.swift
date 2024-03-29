//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import CoreLocation
import Foundation
import PromiseKit

public final class ThreemaUtility: NSObject {
    
    static let postalAddressFormatter: CNPostalAddressFormatter = {
        let formatter = CNPostalAddressFormatter()
        formatter.style = .mailingAddress
        return formatter
    }()
        
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()
    
    /// Format: 4.7b2687
    /// Format Work: 4.7kb2687
    /// Format TestFlight: 4.7b2687-T
    public static let appAndBuildVersion: String = {
        guard let mainBundle = BundleUtil.mainBundle() else {
            return "Unknown"
        }
        
        let version = mainBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let suffix = mainBundle.object(forInfoDictionaryKey: "ThreemaVersionSuffix") as! String
        let build = mainBundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        
        return "\(version)\(suffix)b\(build)\(ThreemaEnvironment.env().description())"
    }()
    
    /// Format: 4.7 (2687)
    /// Format Work: 4.7k (2687)
    /// Format TestFlight: 4.7 (2687-T)
    public static let appAndBuildVersionPretty: String = {
        guard let mainBundle = BundleUtil.mainBundle() else {
            return "Unknown"
        }
        
        let version = mainBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let suffix = mainBundle.object(forInfoDictionaryKey: "ThreemaVersionSuffix") as! String
        let build = mainBundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        
        return "\(version)\(suffix) (\(build)\(ThreemaEnvironment.env().description()))"
    }()
    
    private static let additionalMDMString: String = {
        var mdmDescription = MDMSetup().supportDescriptionString() ?? ""
        if AppGroup.getActiveType() == AppGroupTypeApp {
            let mdmDes = MyIdentityStore.shared().lastWorkInfoMdmDescription
            if mdmDescription != mdmDes {
                MyIdentityStore.shared().lastWorkInfoMdmDescription = mdmDescription
            }
        }
        else {
            if let mdmDesc = MyIdentityStore.shared().lastWorkInfoMdmDescription {
                mdmDescription = mdmDesc
            }
        }
        
        return mdmDescription
    }()
    
    /// Format: 4.7b2687;de/CH;iPhone7,2;15.1
    @objc public static let clientVersion: String = {
        var language = Locale.current.languageCode ?? "?"
        // call clientVersionMDMString to save it
        let mdmDescription = additionalMDMString
        let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode)

        if AppGroup.getActiveType() == AppGroupTypeApp {
            let lang = MyIdentityStore.shared().lastWorkInfoLanguage
            if language != lang {
                MyIdentityStore.shared().lastWorkInfoLanguage = language
            }
        }
        else {
            if let lang = MyIdentityStore.shared().lastWorkInfoLanguage {
                language = lang
            }
        }
        
        return "\(appAndBuildVersion);I;\(language)/\(countryCode ?? "?");\(ThreemaUtility.modelName);\(UIDevice.current.systemVersion)"
    }()
    
    @objc public static let clientVersionWithMDM: String = {
        if !additionalMDMString.isEmpty {
            return clientVersion + ";" + additionalMDMString
        }
        return clientVersion
    }()
    
    // MARK: - Other threema type
    
    @objc public static let isWorkFlavor = ThreemaApp.current == .work ||
        ThreemaApp.current == .workRed ||
        ThreemaApp.current == .onPrem
    
    // TODO: (IOS-4362) Move into `ThreemaEnvironment`
    @objc public static var supportsForwardSecurity: Bool {
        let bi = BusinessInjector()
        if bi.userSettings.enableMultiDevice {
            return false
        }
        
        return true
    }
    
    /// Icon to show if `Contact.showOtherThreemaIcon` is `true`
    ///
    /// If you need a view for it use `OtherThreemaTypeImageView`
    public static var otherThreemaTypeIcon: UIImage {
        if isWorkFlavor {
            return StyleKit.houseIcon
        }
        else {
            return StyleKit.workIcon
        }
    }
    
    /// Accessibility label to use if `Contact.showOtherThreemaIcon` is `true`
    public static var otherThreemaTypeAccessibilityLabel: String {
        if isWorkFlavor {
            return BundleUtil.localizedString(forKey: "threema_type_icon_private_accessibility_label")
        }
        else {
            return BundleUtil.localizedString(forKey: "threema_type_icon_work_accessibility_label")
        }
    }
    
    /// Checks if the otherTypeIcon should be hidden for a given contact
    /// - Parameter contact: Contact to check
    /// - Returns: Bool that states if icon should be hidden
    @available(*, deprecated, message: "Use ContactEntity.showOtherThreemaTypeIcon instead")
    public static func shouldHideOtherTypeIcon(for contact: ContactEntity?) -> Bool {
        
        guard let contact else {
            return true
        }
        
        if contact.isEchoEcho() || contact.isGatewayID() || LicenseStore.isOnPrem() {
            return true
        }
        
        if LicenseStore.requiresLicenseKey() {
            return UserSettings.shared().workIdentities.contains(contact.identity)
        }
        else {
            return !UserSettings.shared().workIdentities.contains(contact.identity)
        }
    }
    
    // MARK: - POI
    
    /// Fetches the address given a location if the privacy setting is enabled, else returns coordinate string
    /// - Parameters:
    /// - location: Location to fetch address for
    /// - completionHandler: Returns address or coordinate string
    @objc static func fetchAddressObjc(for location: CLLocation, completionHandler: @escaping (String) -> Void) {
        fetchAddress(for: location)
            .done { address in
                completionHandler(address)
            }
    }
    
    /// Fetches the address given a location if the privacy setting is enabled, else returns coordinate string
    /// - Parameter location: Location to fetch address for
    /// - Returns: Guarantee with address or coordinate string
    static func fetchAddress(for location: CLLocation) -> Guarantee<String> {
        Guarantee { seal in
            let coordinates = String(
                format: "%.5f°, %.5f°",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
            
            // Don't fetch address if POI are disabled in privacy settings
            guard UserSettings.shared().enablePoi else {
                seal(coordinates)
                return
            }
            
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale.current) { placemarks, error in
                
                if let error {
                    DDLogError("Reverse geocoding failed: \(error)")
                    seal(coordinates)
                    return
                }
                
                guard let placemark = placemarks?.first, let postalAddress = placemark.postalAddress else {
                    seal(coordinates)
                    return
                }
                // Format address and return it
                seal(postalAddressFormatter.string(from: postalAddress))
            }
        }
    }
    
    /// Fire a local push notification
    /// - Parameters:
    ///   - identifier: Identifier of the notification
    ///   - title: Title of the notification
    ///   - body: Body of the notification
    ///   - badge: Badge count of the notification
    ///   - userInfo: UserInfo of the notification
    ///   - completionHandler: completionHandler
    public static func showLocalNotification(
        identifier: String,
        title: String,
        body: String,
        badge: Int,
        userInfo: [AnyHashable: Any]?,
        completionHandler: (() -> Void)? = nil
    ) {
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        notification.badge = NSNumber(integerLiteral: badge)
        
        if let userInfo {
            notification.userInfo = userInfo
        }
        
        if let pushGroupSound = UserSettings.shared().pushGroupSound,
           pushGroupSound != "none" {
            notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(pushGroupSound).caf"))
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: notification, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in
            completionHandler?()
        }
    }
    
    /// Fire a local notification when disconnect from Threema Web
    /// - Parameter entityManager: EntityManager to load the unread messages count
    public static func sendThreemaWebConnectionLostLocalNotification(entityManager: EntityManager) {
        let unreadMessages = UnreadMessages(entityManager: entityManager, taskManager: TaskManager())
        showLocalNotification(
            identifier: "threemaWeb",
            title: BundleUtil.localizedString(forKey: "notification_threemaweb_connectionlost_title"),
            body: BundleUtil.localizedString(forKey: "notification_threemaweb_connectionlost_body"),
            badge: unreadMessages.totalCount(),
            userInfo: nil
        )
    }
    
    // MARK: - String Conversions
    
    /// Trims whiteSpaces and newlines as well as (U+FFFC) from string
    /// - Parameter string: String to trim
    /// - Returns: Trimmed string
    public static func trimCharacters(in string: String) -> String {
        // Remove text attachments from the string we want to send.
        // If we do not remove this we'll be able to send "empty" messages.
        // This character usually gets inserted when showing the microphone icon in the text field when using dictation
        // from iOS.
        // https://stackoverflow.com/questions/41564176/remove-u-0000fffc-unicode-scalar-from-string/45058555#45058555
        // https://www.fileformat.info/info/unicode/char/fffc/index.htm
        let sanitized = string.trimmingCharacters(in: ["\u{fffc}"])
        
        // Trim general whitespace
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
