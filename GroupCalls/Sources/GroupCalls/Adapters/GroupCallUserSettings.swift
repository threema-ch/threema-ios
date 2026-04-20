import Foundation

/// Threema UserSettings representation used to inject the user settings into the framework
public protocol GroupCallUserSettingsProtocol {
    var ipv6Enabled: Bool { get }
}

/// Threema UserSettings representation used to inject the user settings into the framework
public struct GroupCallUserSettings: GroupCallUserSettingsProtocol {
    // MARK: - Public Properties

    public let ipv6Enabled: Bool
    
    // MARK: - Lifecycle

    public init(ipv6Enabled: Bool) {
        self.ipv6Enabled = ipv6Enabled
    }
}
