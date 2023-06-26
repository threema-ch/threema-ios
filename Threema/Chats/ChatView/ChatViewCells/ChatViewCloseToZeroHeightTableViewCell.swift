//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
