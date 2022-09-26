//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
