import Foundation

public enum TargetManager {
    case threema
    case work
    case green
    case blue
    case onPrem
    case customOnPrem
    
    public static let current: TargetManager = {
        switch BundleUtil.targetManagerKey() {
        case "Threema":
            .threema
        case "ThreemaGreen":
            .green
        case "ThreemaWork":
            .work
        case "ThreemaBlue":
            .blue
        case "ThreemaOnPrem":
            .onPrem
        case "CustomOnPrem":
            .customOnPrem
        case let .some(bundleName):
            fatalError("There is a unknown bundle id \(bundleName)")
        case .none:
            handleNoneTargetManager()
        }
    }()
    
    /// Verify the appropriate course of action in the event that the targetManagerKey is not set.
    /// - Returns: TargetManager
    private static func handleNoneTargetManager() -> TargetManager {
        guard !ProcessInfoHelper.isRunningForTests else {
            return .threema
        }

        guard ProcessInfoHelper.isRunningForScreenshots else {
            fatalError("There is no bundle id")
        }
        switch ProcessInfoHelper.targetManagerKeyForScreenshots {
        case "Threema":
            return .threema
        case "ThreemaWork":
            return .work
        case "ThreemaOnPrem":
            return .onPrem
        default:
            fatalError("There is no target manager key for screenshots")
        }
    }
    
    /// Returns the CFBundleName for the current process. E.g. `ThreemaShareExtension` for the share extension or
    /// `Threema` for the app.
    /// See `appName`
    public static let targetName: String = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the CFBundleName for the app to which the current process belongs. E.g. if we are running in the
    /// ThreemaShareExtension this will return `Threema`.
    /// See `currentName`
    public static let appName: String = BundleUtil.mainBundle()?
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the localized app name to be used before ID or Call
    /// For example for Threema Work or Threema OnPrem this would be equal to Threema
    public static let localizedAppName: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "LocalizedAppName") as? String else {
            return "Threema"
        }
        
        return string
    }()
    
    /// Returns the configured url scheme of the app
    public static let appURLScheme: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "AppURLScheme") as? String else {
            return "threema"
        }
        
        return string
    }()
    
    /// Link to open for writing an AppStore review
    public static let rateLink: URL? = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "ThreemaRateLink") as? String,
              let url = URL(string: string) else {
            return nil
        }
        
        return url
    }()
    
    public static let isSandbox =
        switch current {
        case .green, .blue:
            true
        case .threema, .work, .onPrem, .customOnPrem:
            false
        }
    
    public static let isBusinessApp =
        switch current {
        case .work, .blue, .onPrem, .customOnPrem:
            true
        case .threema, .green:
            false
        }
    
    public static let isWork =
        switch current {
        case .work, .blue:
            true
        case .threema, .green, .onPrem, .customOnPrem:
            false
        }
    
    public static let isOnPrem =
        switch current {
        case .onPrem, .customOnPrem:
            true
        case .threema, .green, .work, .blue:
            false
        }
    
    public static let isCustomOnPrem = current == .customOnPrem
}

@available(swift, obsoleted: 1.0, renamed: "TargetManager", message: "Only use from Objective-C")
public final class TargetManagerObjC: NSObject {
    
    @objc public enum TargetManager: Int, RawRepresentable {
        case threema
        case work
        case green
        case blue
        case onPrem
        case customOnPrem
    }
    
    @objc public static let current: TargetManager = {
        guard !ProcessInfoHelper.isRunningForTests else {
            return .threema
        }
        
        switch BundleUtil.targetManagerKey() {
        case "Threema":
            return .threema
        case "ThreemaGreen":
            return .green
        case "ThreemaWork":
            return .work
        case "ThreemaBlue":
            return .blue
        case "ThreemaOnPrem":
            return .onPrem
        case "CustomOnPrem":
            return .customOnPrem
        case let .some(key):
            fatalError("There is a unknown target manager key \(key)")
        case .none:
            return handleNoneTargetManager()
        }
    }()
    
    /// Verify the appropriate course of action in the event that the targetManagerKey is not set.
    /// - Returns: TargetManager
    private static func handleNoneTargetManager() -> TargetManager {
        guard ProcessInfoHelper.isRunningForScreenshots else {
            fatalError("There is no bundle id")
        }
        switch ProcessInfoHelper.targetManagerKeyForScreenshots {
        case "Threema":
            return .threema
        case "ThreemaWork":
            return .work
        case "ThreemaOnPrem":
            return .onPrem
        default:
            fatalError("There is no target manager key for screenshots")
        }
    }
    
    @objc public static let targetName: String = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    @objc public static let appName: String = BundleUtil.mainBundle()?
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the localized app name to be used before ID or Call
    /// For example for Threema Work or Threema OnPrem this would be equal to Threema
    @objc public static let localizedAppName: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "LocalizedAppName") as? String else {
            return "Threema"
        }
        
        return string
    }()
    
    /// Returns the configured url scheme of the app
    @objc public static let appURLScheme: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "AppURLScheme") as? String else {
            return "threema"
        }
        
        return string
    }()
    
    @objc public static let isSandbox =
        switch current {
        case .green, .blue:
            true
        case .threema, .work, .onPrem, .customOnPrem:
            false
        }
    
    @objc static let isBusinessApp =
        switch current {
        case .work, .blue, .onPrem, .customOnPrem:
            true
        case .threema, .green:
            false
        }
    
    @objc static let isWork =
        switch current {
        case .work, .blue:
            true
        case .threema, .green, .onPrem, .customOnPrem:
            false
        }
    
    @objc static let isOnPrem =
        switch current {
        case .onPrem, .customOnPrem:
            true
        case .threema, .green, .work, .blue:
            false
        }
    
    @objc static let isCustomOnPrem = current == .customOnPrem
}
