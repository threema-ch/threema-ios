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

class ForwardSecurityDataAccept: ForwardSecurityData {
    let ephemeralPublicKey: Data
    
    init(sessionID: DHSessionID, ephemeralPublicKey: Data) throws {
        if ephemeralPublicKey.count != kNaClCryptoSymmKeySize {
            throw ForwardSecurityError.invalidPublicKeyLength
        }
        self.ephemeralPublicKey = ephemeralPublicKey
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_ForwardSecurityEnvelope()
        pb.sessionID = sessionID.value
        var pbAccept = CspE2eFs_ForwardSecurityEnvelope.Accept()
        pbAccept.ephemeralPublicKey = ephemeralPublicKey
        pb.content = CspE2eFs_ForwardSecurityEnvelope.OneOf_Content.accept(pbAccept)
        return try pb.serializedData()
    }
}
