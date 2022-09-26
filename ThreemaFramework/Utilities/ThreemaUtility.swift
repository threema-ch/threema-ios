//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import CoreLocation
import Foundation

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
        
        return "\(version)\(suffix)b\(build)\(Environment.env().description())"
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
        
        return "\(version)\(suffix) (\(build)\(Environment.env().description()))"
    }()
    
    /// Format: 4.7b2687;de/CH;iPhone7,2;15.1
    @objc public static let clientVersion: String = {
        let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode)
        let mdmDescription = MDMSetup().supportDescriptionString()?.appending(";") ?? ""
        return "\(appAndBuildVersion);\(mdmDescription)I;\(Locale.current.languageCode ?? "?")/\(countryCode ?? "?");\(ThreemaUtility.modelName);\(UIDevice.current.systemVersion)"
    }()
    
    /// Fetches an Address of a given Location and creates a localized Address-String
    /// - Parameters:
    ///   - location: Location of Address to be fetched
    ///   - completion: Closure that returns the formatted Address-String or nil if no address was resolved for the location
    ///   - onError: Closure that gets called when an error occurs
    @objc public static func fetchAddress(
        for location: CLLocation,
        completion: @escaping (String?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        
        // Don't fetch address if POI are disabled in privacy settings
        guard UserSettings.shared().enablePoi else {
            completion(nil)
            return
        }
        
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale.current) { placemarks, error in
            
            if let error = error {
                onError(error)
                return
            }
            
            guard let placemark = placemarks?.first, let postalAddress = placemark.postalAddress else {
                completion(nil)
                return
            }
            // Format address and return it
            completion(postalAddressFormatter.string(from: postalAddress))
        }
    }
    
    /// Fire a local push notification
    /// - Parameters:
    ///   - identifier: Identifier of the notification
    ///   - title: Tilte of the notification
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
        
        if let userInfo = userInfo {
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
        let unreadMessages = UnreadMessages(entityManager: entityManager)
        showLocalNotification(
            identifier: "threemaWeb",
            title: BundleUtil.localizedString(forKey: "notification_threemaweb_connectionlost_title"),
            body: BundleUtil.localizedString(forKey: "notification_threemaweb_connectionlost_body"),
            badge: unreadMessages.totalCount(),
            userInfo: nil
        )
    }
}
