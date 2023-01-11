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

class ForwardSecurityDataMessage: ForwardSecurityData {
    let type: CspE2eFs_ForwardSecurityEnvelope.Message.DHType
    let counter: UInt64
    let message: Data
    
    init(
        sessionID: DHSessionID,
        type: CspE2eFs_ForwardSecurityEnvelope.Message.DHType,
        counter: UInt64,
        message: Data
    ) {
        self.type = type
        self.counter = counter
        self.message = message
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_ForwardSecurityEnvelope()
        pb.sessionID = sessionID.value
        var pbMessage = CspE2eFs_ForwardSecurityEnvelope.Message()
        pbMessage.dhType = type
        pbMessage.counter = counter
        pbMessage.message = message
        pb.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content.message(pbMessage)
        return try pb.serializedData()
    }
}
