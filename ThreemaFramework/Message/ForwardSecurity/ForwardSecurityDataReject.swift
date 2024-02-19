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
import ThreemaEssentials
import ThreemaProtocols

class ForwardSecurityDataReject: ForwardSecurityData {
    let messageID: Data
    let groupIdentity: GroupIdentity?
    let cause: CspE2eFs_Reject.Cause
        
    init(
        sessionID: DHSessionID,
        messageID: Data,
        groupIdentity: GroupIdentity?,
        cause: CspE2eFs_Reject.Cause
    ) throws {
        if messageID.count != ThreemaProtocol.messageIDLength {
            throw ForwardSecurityError.invalidMessageIDLength
        }
            
        self.messageID = messageID
        self.groupIdentity = groupIdentity
        self.cause = cause
        
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        let envelope = try CspE2eFs_Envelope.with {
            $0.sessionID = sessionID.value
            $0.reject = try CspE2eFs_Reject.with {
                $0.messageID = try messageID.littleEndian()
                if let groupIdentity {
                    $0.groupIdentity = groupIdentity.asCommonGroupIdentity
                }
                $0.cause = cause
            }
        }
        
        return try envelope.serializedData()
    }
}
