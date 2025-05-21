//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

extension BaseMessageEntity {
    
    /// String (of `sectionDate`) used for sectioning messages
    @objc var sectionDateString: String {
        // TODO: (IOS-2393) Use relative dates
        DateFormatter.relativeMediumDate(for: sectionDate)
    }
    
    /// Date that sectioning is based on. (See `sectionDateString`)
    public var sectionDate: Date {
        guard !willBeDeleted else {
            return .now
        }
        
        return date
    }
    
    /// Key paths of properties used for sectioning. Use them to prefetch this information.
    static var sectioningKeyPaths: [Any] { [
        #keyPath(BaseMessageEntity.date),
        #keyPath(BaseMessageEntity.remoteSentDate),
    ] }
}
