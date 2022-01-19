//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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
import ThreemaFramework

class WebCreateContactResponse: WebAbstractMessage {

    var identity: String
    var contact:Contact? = nil
    
    init(request: WebCreateContactRequest) {

        identity = request.identity.uppercased()
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, true, nil)
        
        super.init(messageType: "create", messageSubType: "contact", requestId: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addContact(completion: @escaping () -> ()) {
        let mdmSetup = MDMSetup(setup: false)!
        if mdmSetup.disableAddContact() {
            self.ack!.success = false
            self.ack!.error = "disabledByPolicy"
            self.args = ["identity": self.identity]
            self.data = nil
            completion()
            return
        }
        
        if identity.count != kIdentityLen {
            self.ack!.success = false
            self.ack!.error = "invalidIdentity"
            self.args = ["identity": self.identity]
            self.data = nil
            completion()
            return
        }
        
        ContactStore.shared().addContact(withIdentity: identity, verificationLevel: Int32(kVerificationLevelUnverified), onCompletion: { (theContact, alreadyExisting) in
            if MyIdentityStore.shared().isProvisioned() && self.identity == MyIdentityStore.shared().identity {
                self.ack!.success = false
                self.ack!.error = "invalidIdentity"
                self.args = ["identity": self.identity]
                self.data = nil
                completion()
                return
            }
            
            if theContact == nil {
                self.ack!.success = false
                self.ack!.error = "internalError"
                self.args = ["identity": self.identity]
                self.data = nil
                completion()
                return
            }
            
            self.contact = theContact!
        
            self.ack!.success = true
            self.args = ["identity": self.identity]
            let webContact = WebContact.init(self.contact!)
            self.data = ["receiver": webContact.objectDict()]
            completion()
            return
        }) { (theError) in
            self.ack!.success = false
            self.ack!.error = "invalidIdentity"
            self.args = ["identity": self.identity]
            self.data = nil
            completion()
            return
        }
    }
}
