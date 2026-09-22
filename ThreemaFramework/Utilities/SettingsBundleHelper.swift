import Foundation

public enum SettingsBundleHelper {
    fileprivate enum Keys {
        case safeMode
        case disableSentry
        
        var string: String {
            switch self {
            case .safeMode:
                "safe_mode_switch"
            case .disableSentry:
                "sentry_switch"
            }
        }
    }
    
    public static var safeMode: Bool {
        UserDefaults.standard.bool(forKey: Keys.safeMode.string)
    }
    
    public static var disableSentry: Bool {
        UserDefaults.standard.bool(forKey: Keys.disableSentry.string)
    }
    
    public static func resetSafeMode() {
        UserDefaults.standard.set(false, forKey: Keys.safeMode.string)
    }
}
