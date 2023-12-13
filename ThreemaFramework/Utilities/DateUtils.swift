//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

extension Date {
    public var millisecondsSince1970: UInt64 {
        UInt64((timeIntervalSince1970 * 1000.0).rounded())
    }

    public init(millisecondsSince1970: UInt64) {
        self = Date(timeIntervalSince1970: TimeInterval(millisecondsSince1970) / 1000)
    }
}

extension Date {
    private enum Holder {
        static var _currentDate: Date?
    }
    
    /// Should **only** be used for Testing
    public static var currentDate: Date {
        get {
            Holder._currentDate ?? Date.now
        }
        set {
            #if DEBUG
                Holder._currentDate = newValue
            #endif
            
            // no-op
        }
    }
}
