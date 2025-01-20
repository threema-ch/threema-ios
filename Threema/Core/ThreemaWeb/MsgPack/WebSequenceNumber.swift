//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

class WebSequenceNumber: NSObject {
    private var minValue: UInt64
    private var maxValue: UInt64
    private var _value: UInt64
    var value: UInt64 {
        set {
            if isValid(other: UInt64(newValue)) == true {
                _value = newValue
            }
        }
        get { _value }
    }
    
    init(initialValue: UInt64 = 0, minValue: UInt64, maxValue: UInt64) {
        self.minValue = minValue
        self.maxValue = maxValue
        self._value = initialValue
    }
    
    func isValid(other: UInt64) -> Bool {
        if other < minValue {
            return false
        }
        if other > maxValue {
            return false
        }
        return true
    }
    
    func increment(by: UInt64 = 1) -> UInt64? {
        let tmpValue = _value
        value = tmpValue + by
        return value
    }
}
