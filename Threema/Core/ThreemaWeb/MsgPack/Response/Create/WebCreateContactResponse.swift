//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
    var contact: Contact?
    
    init(request: WebCreateContactRequest) {

        self.identity = request.identity.uppercased()
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, true, nil)
        
        super.init(messageType: "create", messageSubType: "contact", requestID: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addContact(completion: @escaping () -> Void) {
        let mdmSetup = MDMSetup(setup: false)!
        if mdmSetup.disableAddContact() {
            ack!.success = false
            ack!.error = "disabledByPolicy"
            args = ["identity": identity]
            data = nil
            completion()
            return
        }
        
        if identity.count != kIdentityLen {
            ack!.success = false
            ack!.error = "invalidIdentity"
            args = ["identity": identity]
            data = nil
            completion()
            return
        }
        
        ContactStore.shared()
            .addContact(
                with: identity,
                verificationLevel: Int32(kVerificationLevelUnverified),
                onCompletion: { theContact, _ in
                    if MyIdentityStore.shared().isProvisioned(), self.identity == MyIdentityStore.shared().identity {
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
                    let webContact = WebContact(self.contact!)
                    self.data = ["receiver": webContact.objectDict()]
                    completion()
                }
            ) { _ in
                self.ack!.success = false
                self.ack!.error = "invalidIdentity"
                self.args = ["identity": self.identity]
                self.data = nil
                completion()
            }
    }
}
