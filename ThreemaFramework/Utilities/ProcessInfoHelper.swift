import Foundation

@objc public final class ProcessInfoHelper: NSObject {
    
    @objc public static var isRunningForScreenshots: Bool = ProcessInfo.processInfo.arguments
        .contains("-isRunningForScreenshots")
    
    @objc public static var predefinedThemeLight: Bool = ProcessInfo.processInfo.arguments
        .contains("-predefinedThemeLight")
    
    @objc public static var predefinedThemeDark: Bool = ProcessInfo.processInfo.arguments
        .contains("-predefinedThemeDark")
    
    @objc public static var isRunningForTests: Bool = ProcessInfo.processInfo.arguments
        .contains("-isRunningForTests")
    
    public static var targetManagerKeyForScreenshots: String? = ProcessInfo.processInfo.environment["TargetManagerKey"]
}
