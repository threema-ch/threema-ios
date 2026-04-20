import Foundation

/// Sequence number as defined in various Threema protocol specifications
///
/// Initialized at 0 so the first `next()` number is 1
public class SequenceNumber<T: UnsignedInteger> {
    
    private var current: T = 0
    
    /// Create a new sequence number
    public init() {
        // no-op
    }
    
    /// Get next sequence number
    ///
    /// The first number will be 1.
    ///
    /// - Returns: Next sequence number
    public func next() -> T {
        // This will crash if the sequence number overflows
        current += 1
        return current
    }
}
