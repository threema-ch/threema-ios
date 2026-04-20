import Foundation
import ThreemaEssentials
import ThreemaProtocols

protocol ForwardSecurityStatusListener: AnyObject {
    func newSessionInitiated(session: DHSession, contact: ForwardSecurityContact)
    func responderSessionEstablished(
        session: DHSession,
        contact: ForwardSecurityContact,
        existingSessionPreempted: Bool
    )
    func initiatorSessionEstablished(session: DHSession, contact: ForwardSecurityContact)
    func rejectReceived(
        sessionID: DHSessionID,
        contact: ForwardSecurityContact,
        session: DHSession?,
        rejectedMessageID: Data,
        groupIdentity: GroupIdentity?,
        rejectCause: CspE2eFs_Reject.Cause,
        hasForwardSecuritySupport: Bool
    )
    func sessionNotFound(sessionID: DHSessionID, contact: ForwardSecurityContact)
    func sessionForMessageNotFound(in sessionDescription: String, messageID: String, contact: ForwardSecurityContact)
    func sessionTerminated(
        sessionID: DHSessionID?,
        contact: ForwardSecurityContact,
        sessionUnknown: Bool,
        hasForwardSecuritySupport: Bool
    )
    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int)
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact, messageID: Data)
    func first4DhMessageReceived(session: DHSession, contact: ForwardSecurityContact)
    func versionsUpdated(
        in session: DHSession,
        versionUpdatedSnapshot: UpdatedVersionsSnapshot,
        contact: ForwardSecurityContact
    )
    func messageWithoutFSReceived(in session: DHSession, contactIdentity: String, message: AbstractMessage)
    func updateFeatureMask(for contact: ForwardSecurityContact) async -> Bool
    func illegalSessionState(identity: String, sessionID: DHSessionID)
}

extension ForwardSecurityStatusListener {
    func newSessionInitiated(session: DHSession, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func responderSessionEstablished(
        session: DHSession,
        contact: ForwardSecurityContact,
        existingSessionPreempted: Bool
    ) {
        // empty implementation to allow this method to be optional
    }

    func initiatorSessionEstablished(session: DHSession, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func rejectReceived(
        sessionID: DHSessionID,
        contact: ForwardSecurityContact,
        session: DHSession?,
        rejectedMessageID: Data,
        groupIdentity: GroupIdentity?,
        rejectCause: CspE2eFs_Reject.Cause,
        hasForwardSecuritySupport: Bool
    ) {
        // empty implementation to allow this method to be optional
    }

    func sessionNotFound(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func sessionTerminated(
        sessionID: DHSessionID?,
        contact: ForwardSecurityContact,
        sessionUnknown: Bool,
        hasForwardSecuritySupport: Bool
    ) {
        // empty implementation to allow this method to be optional
    }

    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int) {
        // empty implementation to allow this method to be optional
    }
    
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func first4DhMessageReceived(session: DHSession, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }
    
    func updateFeatureMask(for contact: ForwardSecurityContact) async -> Bool {
        // empty implementation to allow this method to be optional
        true
    }
}
