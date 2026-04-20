import CocoaLumberjackSwift
import CoreLocation
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaMacros

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
        
        return "\(version)\(suffix)b\(build)\(ThreemaEnvironment.env().shortDescription)"
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
        
        return "\(version)\(suffix) (\(build)\(ThreemaEnvironment.env().shortDescription))"
    }()
    
    private static let locale: String = {
        var language = Locale.current.languageCode ?? "?"
        // call clientVersionMDMString to save it
        let mdmDescription = additionalMDMString
        let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode)

        if AppGroup.getCurrentType() == AppGroupTypeApp {
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
        
        return "\(language)/\(countryCode ?? "?")"
    }()
    
    private static let additionalMDMString: String = {
        // Here we need MDM without BusinessInjector, becaus at this point RS is not initialized
        var mdmDescription = MDMSetup(appSetupStateRawValue: AppSetupState.notSetup.rawValue)
            .supportDescriptionString() ?? ""
        if AppGroup.getCurrentType() == AppGroupTypeApp {
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
    
    public static let appInfo = AppInfo(
        version: appAndBuildVersion,
        locale: locale,
        deviceModel: ThreemaUtility.modelName,
        osVersion: UIDevice.current.systemVersion
    )
    
    /// Format: 4.7b2687;de/CH;iPhone7,2;15.1
    @objc public static let clientVersion =
        "\(appInfo.version);I;\(appInfo.locale);\(appInfo.deviceModel);\(appInfo.osVersion)"
    
    @objc public static let clientVersionWithMDM: String = {
        if !additionalMDMString.isEmpty {
            return clientVersion + ";" + additionalMDMString
        }
        return clientVersion
    }()
    
    // MARK: - Other threema type
        
    /// Icon to show if `Contact.showOtherThreemaIcon` is `true`
    ///
    /// If you need a view for it use `OtherThreemaTypeImageView`
    @objc public static var otherThreemaTypeIcon: UIImage {
        if TargetManager.isBusinessApp {
            StyleKit.houseIcon
        }
        else {
            StyleKit.workIcon
        }
    }
    
    /// Accessibility label to use if `Contact.showOtherThreemaIcon` is `true`
    public static var otherThreemaTypeAccessibilityLabel: String {
        if TargetManager.isBusinessApp {
            #localize("threema_type_icon_private_accessibility_label")
        }
        else {
            #localize("threema_type_icon_work_accessibility_label")
        }
    }
    
    /// Checks if the otherTypeIcon should be hidden for a given contact
    /// - Parameter contact: Contact to check
    /// - Returns: Bool that states if icon should be hidden
    @available(*, deprecated, renamed: "ContactEntity.showOtherThreemaTypeIcon")
    public static func shouldHideOtherTypeIcon(for contact: ContactEntity?) -> Bool {
        
        guard let contact else {
            return true
        }
        
        if contact.isEchoEcho || contact.isGatewayID || TargetManager.isOnPrem {
            return true
        }
        
        if TargetManager.isBusinessApp {
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
    @available(swift, obsoleted: 1.0, renamed: "fetchAddress(for:)", message: "Only use from Objective-C")
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
            title: #localize("notification_threemaweb_connectionlost_title"),
            body: #localize("notification_threemaweb_connectionlost_body"),
            badge: unreadMessages.totalCount(),
            userInfo: nil
        )
    }
    
    /// Fire a local notification when microphone permission is not set or denied
    /// - Parameter entityManager: EntityManager to load the unread messages count
    public static func sendMicrophonePermissionErrorLocalNotification(entityManager: EntityManager) {
        let unreadMessages = UnreadMessages(entityManager: entityManager, taskManager: TaskManager())
        ThreemaUtility.showLocalNotification(
            identifier: "microphonePermissionError",
            title: String.localizedStringWithFormat(
                #localize("notification_no_access_microphone_title"),
                TargetManager.localizedAppName
            ),
            body: String.localizedStringWithFormat(
                #localize("notification_no_access_microphone_body"),
                TargetManager.appName
            ),
            badge: unreadMessages.totalCount(),
            userInfo: ["threema": ["cmd": "microphonePermissionError"]]
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
    
    public static func accessibilityString(atTime timeInterval: TimeInterval, with prefixKey: String) -> String {
        let accessibilityTime = accessibilityTimeString(for: Int(timeInterval))
        return String.localizedStringWithFormat("%@ %@", prefixKey, accessibilityTime)
    }
    
    public static func accessibilityTimeString(for totalSeconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.collapsesLargestUnit = true
        formatter.allowedUnits = [.minute, .second]
        
        return formatter.string(from: .init(totalSeconds)) ?? ""
    }
    
    /// Trims a given message be of`kMaxMessageLen` length at most
    /// - Parameter text: Text to check
    /// - Returns: Array containing split messages, or the original text if it was short enough
    public static func trimMessageText(text: String, length: Int = Int(kMaxMessageLen)) -> [String] {
       
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return []
        }
        
        // If the text is shorter than the max length, we return directly
        if Data(text.utf8).count <= length {
            return [text]
        }
        
        var remainingMessage = text
        var trimmedMessages = [String]()
        var tempTrimmedMessage = text
        
        while !remainingMessage.isEmpty {
            var stringToCheck: String
            
            if Data(tempTrimmedMessage.utf8).count <= length {
                stringToCheck = tempTrimmedMessage
            }
            else {
                if let lastSpace = tempTrimmedMessage.lastIndex(of: " ") {
                    let postSpaceCount = tempTrimmedMessage.distance(from: lastSpace, to: tempTrimmedMessage.endIndex)
                    stringToCheck = String(tempTrimmedMessage.dropLast(postSpaceCount))
                    
                    if stringToCheck.isEmpty {
                        remainingMessage = String(remainingMessage.dropFirst())
                        stringToCheck = String(tempTrimmedMessage.dropFirst())
                    }
                }
                else {
                    stringToCheck = String(tempTrimmedMessage.dropLast())
                }
            }

            if Data(stringToCheck.utf8).count <= length {
                trimmedMessages.append(stringToCheck)
                remainingMessage = String(remainingMessage.dropFirst(stringToCheck.count))
                tempTrimmedMessage = remainingMessage
                if tempTrimmedMessage.isEmpty {
                    break
                }
            }
            else {
                tempTrimmedMessage = stringToCheck
            }
        }
        
        return trimmedMessages.map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    public static func formatDataLength(_ numBytes: Float) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true

        return formatter.string(fromByteCount: Int64(numBytes))
    }
}
