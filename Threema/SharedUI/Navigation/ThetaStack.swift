/// A class designed to manage and restore view controller stacks across multiple indices.
///
/// The name "ThetaStack" draws inspiration from neuroscience, where theta waves in the brain are associated with memory
/// encoding and spatial navigation. Similar to how theta waves facilitate spatial navigation and memory formation in
/// the brain, this class encodes and retrieves navigation states (stacks of view controllers) for different contexts or
/// indices.
public final class ThetaStack {

    private(set) var stacks: [ThreemaTab: [UIViewController]]
    
    public init() {
        self.stacks = [:]
    }

    /// Stores a stack of view controllers for a specific index.
    ///
    /// - Parameters:
    ///   - stack: An array of `UIViewController` objects to store.
    ///   - index: The integer key used to identify and retrieve this stack later.
    public func store(stack: [UIViewController], for index: ThreemaTab) {
        stacks[index] = stack
    }

    /// Restores the stack of view controllers associated with a given index.
    ///
    /// - Parameter index: The integer key identifying which stack to restore.
    /// - Returns: An array of `UIViewController` objects stored at the specified index, or an empty array if none
    /// exists for that index.
    public func restore(for index: ThreemaTab) -> [UIViewController] {
        stacks[index] ?? []
    }
}
