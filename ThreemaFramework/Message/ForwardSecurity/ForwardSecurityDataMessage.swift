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

import Foundation
import ThreemaProtocols

class ForwardSecurityDataMessage: ForwardSecurityData {
    let type: CspE2eFs_Encapsulated.DHType
    let counter: UInt64
    let message: Data
    let offeredVersion: CspE2eFs_Version
    let appliedVersion: CspE2eFs_Version
    
    init(
        sessionID: DHSessionID,
        type: CspE2eFs_Encapsulated.DHType,
        offeredVersion: CspE2eFs_Version,
        appliedVersion: CspE2eFs_Version,
        counter: UInt64,
        message: Data
    ) {
        self.type = type
        self.offeredVersion = offeredVersion
        self.appliedVersion = appliedVersion
        self.counter = counter
        self.message = message
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_Envelope()
        pb.sessionID = sessionID.value
        var pbMessage = CspE2eFs_Encapsulated()
        pbMessage.dhType = type
        pbMessage.offeredVersion = UInt32(offeredVersion.rawValue)
        pbMessage.appliedVersion = UInt32(appliedVersion.rawValue)
        pbMessage.counter = counter
        pbMessage.encryptedInner = message
        pb.content = CspE2eFs_Envelope.OneOf_Content.encapsulated(pbMessage)
        return try pb.serializedData()
    }
}
