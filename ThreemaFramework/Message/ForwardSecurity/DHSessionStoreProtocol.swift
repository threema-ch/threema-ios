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
