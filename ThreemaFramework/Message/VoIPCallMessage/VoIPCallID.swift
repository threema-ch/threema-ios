//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc public class VoIPCallID: NSObject {
    public var callID: UInt32
    
    public init(callID: UInt32?) {
        guard let callID = callID else {
            self.callID = 0
            return
        }
        self.callID = callID
    }
    
    /// Compare callIDs. Also return true if receivedCallID is 0.
    /// - parameter receivedCallID: VoIPCallID
    /// - returns: true or false
    public func isSame(_ receivedCallID: VoIPCallID) -> Bool {
        callID == receivedCallID.callID || receivedCallID.callID == 0
    }
    
    public class func generate() -> VoIPCallID {
        VoIPCallID(callID: UInt32.random(in: 0...UInt32.max))
    }
}
