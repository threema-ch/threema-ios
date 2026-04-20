import Foundation
@testable import GroupCalls

final class MockGroupCallSessionHelper: GroupCallSessionHelperProtocol {
    func setHasActiveGroupCall(to isActive: Bool, groupName: String?) {
        // No-op
    }
}
