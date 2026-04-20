import Foundation

/// Contains the scroll state that should be persisted between `willApplySnapshot(currentDoesIncludeNewestMessage:)` and
/// `didApplySnapshot(delegateScrollCompletion:)` of the table view in the ChatViewController
///
/// In the future this could also contain variables like `isApplyingSnapshot`, `isDragging` etc.
struct ChatViewScrollState {
    /// The rectangle of an arbitrary cell that is rendered on screen / whose exact position is known before and after
    /// the snapshot has been applied
    /// Currently the newest visible cell is used
    var cellRect: CGRect
    /// Item Identifier for the cell whose rect we have used above
    var cellType: ChatViewDataSource.CellType
    /// The y value of the `contentOffset` in `willApplySnapshot(currentDoesIncludeNewestMessage:)`
    var contentOffsetY: CGFloat
}
