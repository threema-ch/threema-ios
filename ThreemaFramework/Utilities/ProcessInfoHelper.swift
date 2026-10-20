import Foundation

public final class ProcessInfoHelper: NSObject {
    
    @objc public static var isRunningForScreenshots: Bool = ProcessInfo.processInfo.arguments
        .contains("-isRunningForScreenshots")
    
    @objc public static var predefinedThemeLight: Bool = ProcessInfo.processInfo.arguments
        .contains("-predefinedThemeLight")
    
    @objc public static var predefinedThemeDark: Bool = ProcessInfo.processInfo.arguments
        .contains("-predefinedThemeDark")
    
    public static var isRunningForTests: Bool = ProcessInfo.processInfo.arguments
        .contains("-isRunningForTests")

    public static var isRunningAsTestHost: Bool = ProcessInfo.processInfo
        .environment["XCTestConfigurationFilePath"] != nil

    public static var isRunningForPreviews: Bool = ProcessInfo.processInfo
        .environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    public static var isRunningForPlaygrounds: Bool = ProcessInfo.processInfo
        .environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    
    public static var targetManagerKeyForScreenshots: String? = ProcessInfo.processInfo.environment["TargetManagerKey"]
}
