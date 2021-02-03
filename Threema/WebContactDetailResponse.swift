//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class WebContactDetailResponse: WebAbstractMessage {
    
    var contact: Contact?
    var identity: String
    var systemContact: [AnyHashable:Any?]?
    
    init(contact: Contact?, contactDetailRequest: WebContactDetailRequest) {
        identity = contactDetailRequest.identity
        var tmpAck = WebAbstractMessageAcknowledgement.init(contactDetailRequest.requestId, true, nil)
        
        let tmpArgs:[AnyHashable:Any?] = ["identity": self.identity]
        
        var tmpData: [AnyHashable:Any?]? = ["receiver": []]
        
        if contact != nil {
            self.contact = contact
            
            let emails:Array<Any>? = ContactStore.shared().cnContactEmails(for: contact)
            let phoneNumbers:Array<Any>? = ContactStore.shared().cnContactPhoneNumbers(for: contact)
            
            if (emails != nil || phoneNumbers != nil) {
                self.systemContact = ["emails": emails, "phoneNumbers": phoneNumbers]
                tmpData = ["receiver": ["systemContact": self.systemContact]]
            }
            tmpAck.success = true
        } else {
            tmpAck.success = false
            tmpAck.error = "invalid_contact"
            tmpData = nil
        }
        
        super.init(messageType: "response", messageSubType: "contactDetail", requestId: nil, ack: tmpAck, args: tmpArgs, data: tmpData)
    }
}
