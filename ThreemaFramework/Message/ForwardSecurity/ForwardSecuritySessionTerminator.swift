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

public class ForwardSecuritySessionTerminator {
    let businessInjector: BusinessInjector
    let store: SQLDHSessionStore
    
    public init(businessInjector: BusinessInjector, store: SQLDHSessionStore? = nil) throws {
        self.businessInjector = businessInjector
        
        let newStore = try SQLDHSessionStore()
        self.store = store ?? newStore
    }
    
    public func terminateAllSessions(with contact: Contact) throws {
        while let session = try store.bestDHSession(
            myIdentity: businessInjector.myIdentityStore.identity,
            peerIdentity: contact.identity
        ) {
            let terminate = ForwardSecurityDataTerminate(sessionID: session.id)
            let message = ForwardSecurityEnvelopeMessage(data: terminate)
            message.toIdentity = contact.identity
            
            MessageSender.send(message, isPersistent: true)
            
            if try store.deleteDHSession(
                myIdentity: businessInjector.myIdentityStore.identity,
                peerIdentity: contact.identity,
                sessionID: session.id
            ) {
                return
            }
        }
    }
}
