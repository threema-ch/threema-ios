import Foundation
@testable import GroupCalls

final class MockGroupCallUserSettings: GroupCallUserSettingsProtocol {
    var ipv6Enabled: Bool
    var disableProximityMonitoring: Bool
    
    init(ipv6Enabled: Bool, disableProximityMonitoring: Bool) {
        self.ipv6Enabled = ipv6Enabled
        self.disableProximityMonitoring = disableProximityMonitoring
    }
}
