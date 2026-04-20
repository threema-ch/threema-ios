import Foundation

@globalActor
/// Global actor on which almost all things related to group call state should run
public enum GlobalGroupCallActor {
    public actor InternalActor { }
    public static let shared = InternalActor()
}
