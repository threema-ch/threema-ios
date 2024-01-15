//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
