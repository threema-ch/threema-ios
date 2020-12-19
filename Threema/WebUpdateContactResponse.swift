//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class WebUpdateContactResponse: WebAbstractMessage {
    
    var id: String
    var receiver: [AnyHashable: Any?]?
    
    init(request: WebUpdateContactRequest) {
        if request.contact != nil {
            id = request.contact!.identity
            let contact = WebContact.init(request.contact!)
            receiver = contact.objectDict()
            
            let tmpArgs:[AnyHashable:Any?] = ["id": id]
            var tmpData:[AnyHashable:Any?] = [AnyHashable:Any?]()
            
            if receiver != nil {
                tmpData.updateValue(receiver, forKey: "receiver")
            }
            
            super.init(messageType: "update", messageSubType: "contact", requestId: nil, ack: request.ack, args: tmpArgs, data: tmpData)
        } else {
            id = request.contact!.identity
             super.init(messageType: "update", messageSubType: "contact", requestId: nil, ack: request.ack, args: nil, data: nil)
        }
    }
}
