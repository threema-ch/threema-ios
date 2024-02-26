//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
@testable import ThreemaFramework

/// Dummy DH session store for testing purposes only (not optimized).
class InMemoryDHSessionStore: DHSessionStoreProtocol {
    
    // The identifier works as follows: "myIdentity+peerIdentity"
    var hasInvalidSessions = [String: Bool]()
    
    private(set) var dhSessionList: [DHSession] = []
    
    weak var errorHandler: ThreemaFramework.SQLDHSessionStoreErrorHandler?
    
    func exactDHSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID?) throws -> DHSession? {
        for session in dhSessionList {
            if session.myIdentity == myIdentity,
               session.peerIdentity == peerIdentity,
               session.id == sessionID {
                return session
            }
        }
        return nil
    }
    
    func bestDHSession(myIdentity: String, peerIdentity: String) throws -> DHSession? {
        var currentBestSession: DHSession?
        
        for session in dhSessionList {
            if session.myIdentity != myIdentity || session.peerIdentity != peerIdentity {
                continue
            }
            
            if currentBestSession == nil ||
                (currentBestSession?.myRatchet4DH == nil && session.myRatchet4DH != nil) ||
                (session.myRatchet4DH != nil && currentBestSession!.id > session.id) {
                currentBestSession = session
            }
        }
        
        return currentBestSession
    }
    
    func storeDHSession(session: DHSession) throws {
        try deleteDHSession(myIdentity: session.myIdentity, peerIdentity: session.peerIdentity, sessionID: session.id)
        dhSessionList.append(session)
    }
    
    func updateDHSessionRatchets(session: DHSession, peer: Bool) throws {
        guard let localSession = try exactDHSession(
            myIdentity: session.myIdentity,
            peerIdentity: session.peerIdentity,
            sessionID: session.id
        ) else {
            return
        }
        
        if peer {
            if let localRatchet = localSession.peerRatchet2DH, let ratchet = session.peerRatchet2DH,
               localRatchet.counter <= ratchet.counter {
                localSession.peerRatchet2DH = session.peerRatchet2DH
            }
            if let localRatchet = localSession.peerRatchet4DH, let ratchet = session.peerRatchet4DH,
               localRatchet.counter <= ratchet.counter {
                localSession.peerRatchet4DH = session.peerRatchet4DH
            }
        }
        else {
            if let localRatchet = localSession.myRatchet2DH, let ratchet = session.myRatchet2DH,
               localRatchet.counter <= ratchet.counter {
                localSession.myRatchet2DH = session.myRatchet2DH
            }
            if let localRatchet = localSession.myRatchet4DH, let ratchet = session.peerRatchet4DH,
               localRatchet.counter <= ratchet.counter {
                localSession.myRatchet4DH = session.myRatchet4DH
            }
        }
    }
    
    @discardableResult func deleteDHSession(
        myIdentity: String,
        peerIdentity: String,
        sessionID: DHSessionID
    ) throws -> Bool {
        let newDhSessionList = dhSessionList.filter { session in
            !(session.myIdentity == myIdentity && session.peerIdentity == peerIdentity && session.id == sessionID)
        }
        let deleted = newDhSessionList.count != dhSessionList.count
        dhSessionList = newDhSessionList
        return deleted
    }
    
    func deleteAllDHSessions(myIdentity: String, peerIdentity: String) throws -> Int {
        let newDhSessionList = dhSessionList.filter { session in
            !(session.myIdentity == myIdentity && session.peerIdentity == peerIdentity)
        }
        let numDeleted = dhSessionList.count - newDhSessionList.count
        dhSessionList = newDhSessionList
        return numDeleted
    }
    
    func deleteAllDHSessionsExcept(
        myIdentity: String,
        peerIdentity: String,
        excludeSessionID: DHSessionID,
        fourDhOnly: Bool
    ) throws -> Int {
        let newDhSessionList = dhSessionList.filter { session in
            !(
                session.myIdentity == myIdentity && session
                    .peerIdentity == peerIdentity && (!fourDhOnly || session.myRatchet4DH != nil) && excludeSessionID !=
                    session.id
            )
        }
        let numDeleted = dhSessionList.count - newDhSessionList.count
        dhSessionList = newDhSessionList
        return numDeleted
    }
    
    func hasInvalidDHSessions(myIdentity: String, peerIdentity: String) throws -> Bool {
        hasInvalidSessions["\(myIdentity)+\(peerIdentity)"] ?? false
    }
    
    func executeNull() throws {
        // Noop
    }
}
