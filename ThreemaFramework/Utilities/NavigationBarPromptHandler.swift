import Foundation
import GroupCalls
import ThreemaMacros

@objc public final class NavigationBarPromptHandler: NSObject {
    
    @objc public static var isWebActive = false {
        didSet {
            guard isWebActive != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var isCallActiveInBackground = false {
        didSet {
            guard isCallActiveInBackground != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var isGroupCallActive = false {
        didSet {
            guard isGroupCallActive != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var name: String? = nil
        
    public static func getCurrentPrompt(duration: Int?) -> String? {
        
        if isCallActiveInBackground {
            if let duration {
                return "☎️ " + String.localizedStringWithFormat(
                    "%@ - %@",
                    DateFormatter.timeFormatted(duration),
                    name ?? ""
                )
            }
            else {
                return "☎️ " + (name ?? "")
            }
        }
        
        if isGroupCallActive {
            if let name {
                return "☎️ " + "\(#localize("group_call_title")): \(name)"
            }
            else {
                return"☎️ " + #localize("group_call_title")
            }
        }
        
        if isWebActive {
            return "🖥 " + #localize("settings_threema_web_connected")
        }
        
        return nil
    }
    
    public static func shouldShowPrompt() -> Bool {
        isWebActive || isGroupCallActive || isCallActiveInBackground
    }
    
    private static func postChangeNotifications() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationBarColorShouldChange),
                object: nil
            )
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationItemPromptShouldChange),
                object: nil
            )
        }
    }
}
