import Foundation

public final class Colors: NSObject {
    @objc public enum Theme: NSInteger {
        case light
        case dark

        public var name: String {
            switch self {
            case .dark: "Dark"
            case .light: "Light"
            }
        }
    }
    
    @objc public static var theme: Theme = .light {
        didSet {
            StyleKit.resetThemedCache()
            Colors.setupAppearance()
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: kNotificationColorThemeChanged),
                object: nil
            )
        }
    }
             
    @objc public class func resolveTheme() {
        switch UserSettings.shared().interfaceStyle {
        case UIUserInterfaceStyle.light.rawValue:
            Colors.theme = .light

        case UIUserInterfaceStyle.dark.rawValue:
            Colors.theme = .dark

        default:
            let traitCollection = UITraitCollection.current
            let theme = traitCollection.userInterfaceStyle == .dark ? Theme.dark : Theme.light
            Colors.theme = theme
        }
    }
}
