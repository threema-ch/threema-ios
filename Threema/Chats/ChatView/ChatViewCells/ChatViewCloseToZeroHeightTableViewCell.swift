import UIKit

/// A cell with no content & background and the minimal height possible
///
/// Use this if you need to provide a cell to the chat view, but are unable to load the needed content for this cell
/// (e.g. a message that was deleted in the meantime).
final class ChatViewCloseToZeroHeightTableViewCell: ThemedCodeTableViewCell {
    override func configureCell() {
        super.configureCell()
        
        // 0.1 resets the cell to a default height, thus we use 0.1
        defaultMinimalHeightConstraint.constant = 0.2
    }
}

// MARK: - Reusable

extension ChatViewCloseToZeroHeightTableViewCell: Reusable { }
