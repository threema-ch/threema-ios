import Foundation

public enum AppVersionInfo {
    /// App Version and Build number
    public static var appVersion: (version: String?, build: String?) {
        var version = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        var build: String?
        if let suffix = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: "ThreemaVersionSuffix") as? String {
            version = version?.appending(suffix)
            build = BundleUtil.mainBundle()?.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        }
        return (version, build)
    }

    public static var version: (major: Int, minor: Int, maintenance: Int, build: Int) {
        var major = 0
        var minor = 0
        var maintenance = 0
        var build = 0

        let (appVersion, appBuild) = appVersion

        if let versionDigits = appVersion?.split(separator: ".") {
            if versionDigits.count >= 1 {
                major = Int(versionDigits[0]) ?? 0
                if versionDigits.count >= 2 {
                    minor = Int(versionDigits[1]) ?? 0
                    if versionDigits.count >= 3 {
                        maintenance = Int(versionDigits[2]) ?? 0
                    }
                }
            }
        }

        if let appBuild {
            build = Int(appBuild) ?? 0
        }

        return (major, minor, maintenance, build)
    }
}
