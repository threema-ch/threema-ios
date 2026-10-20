import Foundation

@objc public enum EnvironmentType: Int, CustomStringConvertible {
    case appStore
    case testFlight
    case xcode

    public var shortDescription: String {
        switch self {
        case .appStore:
            ""
        case .testFlight:
            "-T"
        case .xcode:
            "-X"
        }
    }

    public var description: String {
        switch self {
        case .appStore:
            "appstore"
        case .testFlight:
            "testflight"
        case .xcode:
            "xcode"
        }
    }

    public static var current: Self {
        #if DEBUG
            return .xcode
        #endif

        // TestFLight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }

        return .appStore
    }
}
