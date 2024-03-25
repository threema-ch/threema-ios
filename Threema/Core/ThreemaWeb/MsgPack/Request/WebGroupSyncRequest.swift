//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

class WebGroupSyncRequest: WebAbstractMessage {
    
    let id: Data
    
    override init(message: WebAbstractMessage) {
        let idString = message.args!["id"] as! String
        self.id = idString.hexadecimal!
        super.init(message: message)
    }
    
    func syncGroup() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let businessInjector = BusinessInjector()
        guard let conversation = businessInjector.entityManager.entityFetcher.legacyConversation(for: id) else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return
        }

        guard let group = businessInjector.groupManager.getGroup(conversation: conversation) else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return
        }
        
        if !group.isOwnGroup {
            ack!.success = false
            ack!.error = "notAllowed"
            return
        }
        
        DispatchQueue.main.async {
            businessInjector.groupManager.sync(group: group)
                .catch { error in
                    DDLogError("Unable to sync group: \(error.localizedDescription)")
                }
        }
        ack!.success = true
    }
}
