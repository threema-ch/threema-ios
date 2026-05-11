import CocoaLumberjackSwift
import Foundation

/// We use this as a fill in for when we are not in the Work environment
public class WorkAvailabilityStatusManagerNull: WorkAvailabilityStatusManagerProtocol {
    public func ownStatus() -> WorkAvailabilityStatus {
        WorkAvailabilityStatus(category: .none, text: nil)
    }
    
    public func setOwnStatus(_ status: WorkAvailabilityStatus?) {
        // no-op
    }
}
