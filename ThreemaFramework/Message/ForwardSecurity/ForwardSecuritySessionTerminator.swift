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

import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

public class ForwardSecuritySessionTerminator {
    let businessInjector: BusinessInjectorProtocol
    let store: DHSessionStoreProtocol
    
    public init(
        businessInjector: BusinessInjectorProtocol = BusinessInjector(),
        store: DHSessionStoreProtocol? = nil
    ) throws {
        self.businessInjector = businessInjector
        
        let newStore = try SQLDHSessionStore()
        self.store = store ?? newStore
    }
    
    /// Terminate all sessions with the provided contact and cause
    ///
    /// - Note: You are responsible that this is called on the correct queue for `contact` and that you save `contact`
    ///         afterwards.
    ///
    /// - Parameters:
    ///   - contact: Contact to terminate all sessions with
    ///   - cause: Cause of termination
    /// - Returns: `true` if there existed any sessions that were terminated
    public func terminateAllSessions(with contact: ContactEntity, cause: CspE2eFs_Terminate.Cause) throws -> Bool {
        guard let myIdentity = businessInjector.myIdentityStore.identity else {
            DDLogError(
                "[ForwardSecurity] Unable to terminate all sessions with \(contact.identity), because no my identity exists"
            )
            return false
        }
        
        if contact.forwardSecurityState.intValue == 1 {
            DDLogVerbose("[ForwardSecurity] Reset FS state for contact \(contact.identity)")
        }
        contact.forwardSecurityState = NSNumber(value: ForwardSecurityState.off.rawValue)
        
        var numberOfSessionsTerminated = 0
        
        while let session = try store.bestDHSession(
            myIdentity: myIdentity,
            peerIdentity: contact.identity
        ) {
            let terminate = ForwardSecurityDataTerminate(sessionID: session.id, cause: cause)
            let message = ForwardSecurityEnvelopeMessage(data: terminate)
            message.toIdentity = contact.identity
            
            businessInjector.messageSender.sendMessage(abstractMessage: message, isPersistent: true)
            
            DDLogNotice("[ForwardSecurity] Terminate FS session with id \(session.id.description)")
            
            try store.deleteDHSession(
                myIdentity: businessInjector.myIdentityStore.identity,
                peerIdentity: contact.identity,
                sessionID: session.id
            )
            
            numberOfSessionsTerminated += 1
        }
        
        return numberOfSessionsTerminated > 0
    }
    
    /// Terminate all sessions with the provided identity and cause
    /// - Parameters:
    ///   - identity: Identity to terminate all sessions with
    ///   - cause: Cause of termination
    /// - Returns: `true` if there existed any sessions that were terminated
    public func terminateAllSessions(with identity: String, cause: CspE2eFs_Terminate.Cause) throws -> Bool {
        try businessInjector.entityManager.performAndWaitSave {
            guard let contact = self.businessInjector.entityManager.entityFetcher.contact(for: identity) else {
                return false
            }
            
            return try self.terminateAllSessions(with: contact, cause: cause)
        }
    }
    
    /// Deletes all sessions with this contact
    /// This shouldn't be used except for debugging. Will crash if FS debug messages are not enabled
    ///
    /// - Parameter contact: The contact whose FS sessions we want to delete
    public func deleteAllSessions(with contact: ContactEntity) throws {
        guard ThreemaEnvironment.fsDebugStatusMessages else {
            fatalError()
        }
        
        let identity = contact.identity
        businessInjector.entityManager.performAndWaitSave {
            guard let contact = self.businessInjector.entityManager.entityFetcher.contact(for: identity) else {
                return
            }
            
            if contact.forwardSecurityState.intValue == 1 {
                DDLogVerbose("[ForwardSecurity] Reset FS state for contact \(identity)")
            }
            
            contact.forwardSecurityState = NSNumber(value: ForwardSecurityState.off.rawValue)
        }
        
        while let session = try store.bestDHSession(
            myIdentity: businessInjector.myIdentityStore.identity,
            peerIdentity: contact.identity
        ) {
            DDLogVerbose("[ForwardSecurity] Delete FS session with id \(session.id.description)")
            
            try store.deleteDHSession(
                myIdentity: businessInjector.myIdentityStore.identity,
                peerIdentity: contact.identity,
                sessionID: session.id
            )
        }
    }
}
