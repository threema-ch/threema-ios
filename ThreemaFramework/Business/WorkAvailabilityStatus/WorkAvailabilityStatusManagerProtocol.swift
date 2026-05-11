import CocoaLumberjackSwift
import Foundation

public protocol WorkAvailabilityStatusManagerProtocol {
    
    /// Fetches the locally persisted status
    /// - Returns: The fetched local status or `.none` if nothing is stored.
    func ownStatus() -> WorkAvailabilityStatus
    
    /// Persists the own status locally
    /// - Parameter status: Status to set
    func setOwnStatus(_ status: WorkAvailabilityStatus?)
}
