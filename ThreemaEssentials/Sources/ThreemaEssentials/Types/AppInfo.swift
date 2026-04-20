/// Information about current app
///
/// Use this to inject information about the current app
///
/// Vision: (IOS-5456) This should be extended to contain all app info (e.g. app name, flavor, environment, feature
/// flags?, ...) and be injected in all the packages that need this information
public struct AppInfo {
    public let version: String
    public let locale: String
    public let deviceModel: String
    public let osVersion: String
    
    public init(version: String, locale: String, deviceModel: String, osVersion: String) {
        self.version = version
        self.locale = locale
        self.deviceModel = deviceModel
        self.osVersion = osVersion
    }
}
