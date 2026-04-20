import Foundation

/// Load data that is needed to store the scroll position
protocol ChatScrollPositionDataProvider {
    /// Top offset of cell
    var minY: CGFloat { get }
    
    // Due to the nature of reusable cells these two properties have to be optional:
    
    /// Managed object ID of message shown in cell
    var messageObjectID: NSManagedObjectID? { get }
    
    /// Date of messages shown in cell (used to look up offset of message in all chat messages)
    var messageDate: Date? { get }
}
