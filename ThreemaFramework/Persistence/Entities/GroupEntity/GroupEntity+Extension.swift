import Foundation

extension GroupEntity {
    @objc public enum GroupState: Int {
        case active, requestedSync, left, forcedLeft
    }
    
    public var didLeave: Bool {
        state.intValue == GroupState.left.rawValue
    }
    
    var didForcedLeave: Bool {
        state.intValue == GroupState.forcedLeft.rawValue
    }
}
