//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

enum CustomContextMenuConfiguration {
    enum Layout {
        static let verticalSpacing = 12.0
        static let leadingTrailingInset = 8.0
    }
    
    enum Animation {
        static let transformUp = CGAffineTransform(scaleX: 1.1, y: 1.1)
        static let transformDown = CGAffineTransform(scaleX: 0.9, y: 0.9)
        static let duration: TimeInterval = 0.4
        static let delay: TimeInterval = 0.0
    }
    
    enum SnapshotView {
        static let shadowRadius = 12.0
        static let shadowOffset = CGSize(width: 0, height: 4)
        static let shadowColor = UIColor.black
        static let shadowOpacity: Float = 0.3
    }
}
