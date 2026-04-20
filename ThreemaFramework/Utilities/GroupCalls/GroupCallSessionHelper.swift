import Foundation
import GroupCalls

/// Handles NavigationBar related functions for group calls
public final class GroupCallSessionHelper: GroupCallSessionHelperProtocol {
    
    public static let shared = GroupCallSessionHelper()
    
    public func setHasActiveGroupCall(to isActive: Bool, groupName: String?) {
        NavigationBarPromptHandler.name = groupName
        NavigationBarPromptHandler.isGroupCallActive = isActive
    }
}
