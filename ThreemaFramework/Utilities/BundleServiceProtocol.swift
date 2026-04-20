public protocol BundleServiceProtocol {
    var mainBundleIdentifier: String? { get }
}

public struct BundleServiceLive: BundleServiceProtocol {
    public var mainBundleIdentifier: String? {
        BundleUtil.mainBundle()?.bundleIdentifier
    }
}

extension BundleServiceProtocol where Self == BundleServiceLive {
    public static var live: BundleServiceProtocol {
        BundleServiceLive()
    }
}
