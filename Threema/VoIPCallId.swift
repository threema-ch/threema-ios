//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

@objc class VoIPCallId: NSObject {
    var callId: UInt32
    
    init(callId: UInt32?) {
        guard let callId = callId else {
            self.callId = 0
            return
        }
        self.callId = callId
    }
    
    /**
    Compare callIds. Also return true if receivedCallId is 0.
    - parameter receivedCallId: VoIPCallId
    - returns: true or false
    */
    func isSame(_ receivedCallId: VoIPCallId) -> Bool {
        return callId == receivedCallId.callId || receivedCallId.callId == 0
    }
    
    class func generate() -> VoIPCallId {
        return VoIPCallId(callId: UInt32.random(in: 0 ... UInt32.max))
    }
}
