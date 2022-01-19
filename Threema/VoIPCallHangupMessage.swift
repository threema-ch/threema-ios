//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc class VoIPCallHangupMessage: NSObject {
    @objc var contact: Contact
    @objc var callId: VoIPCallId
    @objc var completion: (() -> Void)?
    
    @objc init(contact: Contact, callId: VoIPCallId, completion: (() -> Void)?) {
        self.contact = contact
        self.callId = callId
        self.completion = completion
        super.init()
    }
}

extension VoIPCallHangupMessage {
    
    enum VoIPCallHangupMessageError: Error {
        case generateJson(error: Error)
    }
    
    enum Keys: String {
        case callId = "callId"
    }
    
    @objc class func hangupFromJSONDictionary(_ dictionary: [AnyHashable: Any]?, contact: Contact) -> VoIPCallHangupMessage {
        guard let dictionary = dictionary else {
            return VoIPCallHangupMessage(contact: contact, callId: VoIPCallId(callId: nil), completion: nil)
        }
        let tmpCallId = VoIPCallId(callId: dictionary[Keys.callId.rawValue] as? UInt32)
        return VoIPCallHangupMessage(contact: contact, callId: tmpCallId, completion: nil)
    }
    
    @objc func jsonData() throws -> Data {
        let json = [Keys.callId.rawValue: callId.callId] as [AnyHashable : Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch let error {
            throw VoIPCallHangupMessageError.generateJson(error: error)
        }
    }
}
