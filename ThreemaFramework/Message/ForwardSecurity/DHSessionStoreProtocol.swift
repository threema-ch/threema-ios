//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

public protocol DHSessionStoreProtocol: AnyObject {
    var errorHandler: SQLDHSessionStoreErrorHandler? { get set }
    
    func exactDHSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID?) throws -> DHSession?
    func bestDHSession(myIdentity: String, peerIdentity: String) throws -> DHSession?
    func storeDHSession(session: DHSession) throws
    
    /// Update session ratchets
    /// - Parameters:
    ///   - session: Session to persist ratchets for
    ///   - peer: Own or peer ratchets?
    func updateDHSessionRatchets(session: DHSession, peer: Bool) throws
    
    /// Persist `newSessionCommitted`, `lastMessageSent` and versions of `session`
    /// - Parameter session: Session to persist properties for
    func updateNewSessionCommitLastMessageSentDateAndVersions(session: DHSession) throws
    
    @discardableResult func deleteDHSession(
        myIdentity: String, peerIdentity: String, sessionID: DHSessionID
    ) throws -> Bool
    @discardableResult func deleteAllDHSessions(myIdentity: String, peerIdentity: String) throws -> Int
    @discardableResult func deleteAllDHSessionsExcept(
        myIdentity: String,
        peerIdentity: String,
        excludeSessionID: DHSessionID,
        fourDhOnly: Bool
    ) throws -> Int
    
    /// Check if some of the sessions between `myIdentity` and `peerIdentity` are invalid
    ///
    /// Note: In general there exists only one session with a peer.
    ///
    /// - Parameters:
    ///   - myIdentity: My Threema identity
    ///   - peerIdentity: Threema identity of peer
    /// - Returns: `true` if any session is invalid
    func hasInvalidDHSessions(myIdentity: String, peerIdentity: String) throws -> Bool
    
    func executeNull() throws
}
