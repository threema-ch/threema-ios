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

import Foundation

protocol ForwardSecurityStatusListener: AnyObject {
    func newSessionInitiated(session: DHSession, contact: ForwardSecurityContact)
    func responderSessionEstablished(
        session: DHSession,
        contact: ForwardSecurityContact,
        existingSessionPreempted: Bool
    )
    func initiatorSessionEstablished(session: DHSession, contact: ForwardSecurityContact)
    func rejectReceived(sessionID: DHSessionID, contact: ForwardSecurityContact, rejectedMessageID: Data)
    func sessionNotFound(sessionID: DHSessionID, contact: ForwardSecurityContact)
    func sessionBadDhState(sessionID: DHSessionID, contact: ForwardSecurityContact)
    func sessionTerminated(sessionID: DHSessionID, contact: ForwardSecurityContact)
    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int)
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact)
    func messageDecryptionFailed(sessionID: DHSessionID, contact: ForwardSecurityContact, failedMessageID: Data)
    func first4DhMessageReceived(sessionID: DHSessionID, contact: ForwardSecurityContact)
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

    func rejectReceived(sessionID: DHSessionID, contact: ForwardSecurityContact, rejectedMessageID: Data) {
        // empty implementation to allow this method to be optional
    }

    func sessionNotFound(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func sessionBadDhState(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func sessionTerminated(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }

    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int) {
        // empty implementation to allow this method to be optional
    }
    
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }
    
    func messageDecryptionFailed(sessionID: DHSessionID, contact: ForwardSecurityContact, failedMessageID: Data) {
        // empty implementation to allow this method to be optional
    }

    func first4DhMessageReceived(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // empty implementation to allow this method to be optional
    }
}
