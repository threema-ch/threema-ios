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

protocol ForwardSecurityMessageSenderProtocol {
    func send(message: AbstractMessage)
}

@objc public class ForwardSecurityMessageProcessor: NSObject {
    private let dhSessionStore: DHSessionStoreProtocol
    private let identityStore: MyIdentityStoreProtocol
    private let messageSender: ForwardSecurityMessageSenderProtocol
    
    struct Listener {
        weak var listener: ForwardSecurityStatusListener?
    }

    private var listeners = [ObjectIdentifier: Listener]()
    
    init(
        dhSessionStore: DHSessionStoreProtocol,
        identityStore: MyIdentityStoreProtocol,
        messageSender: ForwardSecurityMessageSenderProtocol
    ) {
        self.dhSessionStore = dhSessionStore
        self.identityStore = identityStore
        self.messageSender = messageSender
    }
    
    func processEnvelopeMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) throws -> (AbstractMessage?, DHSession?) {
        switch envelopeMessage.data {
        case let initT as ForwardSecurityDataInit:
            try processInit(sender: sender, initT: initT)
        case let accept as ForwardSecurityDataAccept:
            try processAccept(sender: sender, accept: accept)
        case let reject as ForwardSecurityDataReject:
            try processReject(sender: sender, reject: reject)
        case is ForwardSecurityDataMessage:
            return try processMessage(sender: sender, envelopeMessage: envelopeMessage)
        case let terminate as ForwardSecurityDataTerminate:
            try processTerminate(sender: sender, terminate: terminate)
        default:
            assertionFailure("Unknown forward security message type")
        }
        return (nil, nil)
    }
    
    /// Wrapper for ObjC
    @objc func processEnvelopeMessageObjc(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage,
        sessionP: UnsafeMutablePointer<AnyObject?>,
        errorP: NSErrorPointer
    ) -> AbstractMessage? {
        do {
            let (message, session) = try processEnvelopeMessage(sender: sender, envelopeMessage: envelopeMessage)
            sessionP.pointee = session as AnyObject
            return message
        }
        catch {
            errorP?.pointee = error as NSError
            return nil
        }
    }
    
    @objc func rejectEnvelopeMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) {
        // If this is an actual message, then send a reject back (to be used when we don't support FS)
        do {
            if let msg = envelopeMessage.data as? ForwardSecurityDataMessage {
                DDLogWarn("Rejecting FS message in session ID \(msg.sessionID) from \(sender.identity)")
                
                let reject = try ForwardSecurityDataReject(
                    sessionID: msg.sessionID,
                    rejectedMessageID: envelopeMessage.messageID,
                    cause: .disabled
                )
                sendMessageToContact(contact: sender, message: reject)
            }
        }
        catch {
            // ignored
        }
    }
    
    /// Wrap a message in a forward security envelope.
    ///
    /// - Returns: the wrapped `message`, optionally an auxiliary control message (`auxMessage`) that should be sent *before* the actual message, and the ID of a new session (if one had to be created)
    func makeMessage(
        contact: ForwardSecurityContact,
        innerMessage: AbstractMessage
    ) throws
        -> (
            auxMessage: ForwardSecurityEnvelopeMessage?,
            message: ForwardSecurityEnvelopeMessage,
            sendCompletion: () throws -> Void,
            sendAuxFailure: () -> Void
        ) {
        var initEnvelope: ForwardSecurityEnvelopeMessage?
        
        // Check if we already have a session with this contact
        var newSessionID: DHSessionID?
        let session = try dhSessionStore.bestDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: contact.identity
        ) ?? {
            // Establish a new DH session
            let newSession = DHSession(
                peerIdentity: contact.identity,
                peerPublicKey: contact.publicKey,
                identityStore: identityStore
            )
            newSessionID = newSession.id
            try dhSessionStore.storeDHSession(session: newSession)
            DDLogVerbose("Starting new DH session ID \(newSession.id) with \(contact.identity)")
            notifyListeners { listener in listener.newSessionInitiated(session: newSession, contact: contact) }
            
            // Send init message
            let initMessage = try ForwardSecurityDataInit(
                sessionID: newSession.id,
                ephemeralPublicKey: newSession.myEphemeralPublicKey
            )
            initEnvelope = ForwardSecurityEnvelopeMessage(data: initMessage)
            initEnvelope?.toIdentity = contact.identity
            return newSession
        }()
        
        // Obtain encryption key from ratchet
        let (ratchetv, dhType, forwardSecurityMode): (
            KDFRatchet?,
            CspE2eFs_ForwardSecurityEnvelope.Message.DHType,
            ForwardSecurityMode
        ) = { if session.myRatchet4DH == nil {
            // 2DH mode
            return (
                session.myRatchet2DH,
                CspE2eFs_ForwardSecurityEnvelope.Message.DHType.twodh,
                .twoDH
            )
        }
        else {
            return (
                session.myRatchet4DH,
                CspE2eFs_ForwardSecurityEnvelope.Message.DHType.fourdh,
                .fourDH
            )
        }
        }()
        
        guard let ratchet = ratchetv else {
            throw ForwardSecurityError.noDHModeNegotiated
        }
        
        let currentKey = ratchet.currentEncryptionKey
        let counter = ratchet.counter
            
        // We turn the ratchet only when sending was successful. Otherwise it can happen that the client goes
        // offline just before the message is about to be sent. On the next retry we would use the next key
        // and sequence number causing our contact to think that a message was lost when in fact all were delivered
        let sendCompletion = {
            ratchet.turn()
            
            // Update ratchets in store (don't use storeDHSession(), as otherwise we
            // might overwrite the peer ratchets if an incoming message is being processed
            // for the same session at the same time)
            try self.dhSessionStore.updateDHSessionRatchets(session: session, peer: false)
        }
            
        let sendAuxFailure = {
            // If sending the aux (init) message fails, delete the session again, as the peer won't
            // know about it, and we should create a new session with a new init when we retry.
            if let newSessionID = newSessionID {
                _ = try? self.dhSessionStore.deleteDHSession(
                    myIdentity: self.identityStore.identity,
                    peerIdentity: contact.identity,
                    sessionID: newSessionID
                )
            }
        }
        // Symmetrically encrypt message (type byte + body)
        var plaintext = Data([innerMessage.type()])
        if let quoted = innerMessage as? QuotedMessageProtocol, let quotedBody = quoted.quotedBody() {
            plaintext += quotedBody
        }
        else {
            plaintext += innerMessage.body()
        }
        
        // A new key is used for each message, so the nonce can be zero
        let nonce = Data(count: Int(kNaClCryptoNonceSize))
        let ciphertext = NaClCrypto.shared().symmetricEncryptData(plaintext, withKey: currentKey, nonce: nonce)!

        let dataMessage = ForwardSecurityDataMessage(
            sessionID: session.id,
            type: dhType,
            counter: counter,
            message: ciphertext
        )
        let envelope = ForwardSecurityEnvelopeMessage(data: dataMessage)
        
        // Copy attributes from inner message
        envelope.fromIdentity = innerMessage.fromIdentity
        envelope.toIdentity = innerMessage.toIdentity
        envelope.messageID = innerMessage.messageID
        envelope.date = innerMessage.date
        envelope.flags = innerMessage.flags
        envelope.pushFromName = innerMessage.pushFromName
        envelope.forwardSecurityMode = forwardSecurityMode
        envelope.encapAllowSendingProfile = innerMessage.allowSendingProfile()
        
        if envelope.flags == nil {
            envelope.flags = NSNumber(integerLiteral: 0)
        }
        if innerMessage.flagShouldPush() {
            envelope.flags = envelope.flags.int32Value | MESSAGE_FLAG_SEND_PUSH as NSNumber
        }
        if innerMessage.flagDontQueue() {
            envelope.flags = envelope.flags.int32Value | MESSAGE_FLAG_DONT_QUEUE as NSNumber
        }
        if innerMessage.flagDontAck() {
            envelope.flags = envelope.flags.int32Value | MESSAGE_FLAG_DONT_ACK as NSNumber
        }
        if innerMessage.flagImmediateDeliveryRequired() {
            envelope.flags = envelope.flags.int32Value | MESSAGE_FLAG_IMMEDIATE_DELIVERY as NSNumber
        }

        return (initEnvelope, envelope, sendCompletion, sendAuxFailure)
    }
    
    @objc func hasContactUsedForwardSecurity(contact: ForwardSecurityContact) -> Bool {
        do {
            if let bestSession = try dhSessionStore.bestDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: contact.identity
            ) {
                // Check if any 2DH or 4DH messages have been received by looking at the ratchet count
                if let peerRatchet4DH = bestSession.peerRatchet4DH, peerRatchet4DH.counter > 1 {
                    return true
                }
                else if let peerRatchet2DH = bestSession.peerRatchet2DH, peerRatchet2DH.counter > 1 {
                    return true
                }
            }
        }
        catch {
            // ignored
        }
        
        return false
    }
    
    // MARK: Listeners
    
    func addListener(listener: ForwardSecurityStatusListener) {
        let id = ObjectIdentifier(listener)
        listeners[id] = Listener(listener: listener)
    }
    
    func removeListener(listener: ForwardSecurityStatusListener) {
        let id = ObjectIdentifier(listener)
        listeners.removeValue(forKey: id)
    }
    
    // MARK: Private functions
    
    private func processInit(sender: ForwardSecurityContact, initT: ForwardSecurityDataInit) throws {
        if try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: initT.sessionID
        ) != nil {
            // Silently discard init message for existing session
            return
        }

        // The initiator will only send an Init if it does not have an existing session. This means
        // that any 4DH sessions that we have stored for this contact are obsolete and should be deleted.
        // We will keep 2DH sessions (which will have been initiated by us), as otherwise messages may
        // be lost during Init race conditions.
        var existingSessionPreempted = false
        if try dhSessionStore.deleteAllDHSessionsExcept(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            excludeSessionID: initT.sessionID,
            fourDhOnly: true
        ) > 0 {
            existingSessionPreempted = true
        }
        
        let session = try DHSession(
            id: initT.sessionID,
            peerEphemeralPublicKey: initT.ephemeralPublicKey,
            peerIdentity: sender.identity,
            peerPublicKey: sender.publicKey,
            identityStore: identityStore
        )
        try dhSessionStore.storeDHSession(session: session)
        DDLogVerbose("Responding to new DH session ID \(session.id) request from \(sender.identity)")
        notifyListeners { listener in listener.responderSessionEstablished(
            session: session,
            contact: sender,
            existingSessionPreempted: existingSessionPreempted
        ) }

        // Create and send accept
        let accept = try ForwardSecurityDataAccept(
            sessionID: initT.sessionID,
            ephemeralPublicKey: session.myEphemeralPublicKey
        )
        sendMessageToContact(contact: sender, message: accept)
    }
    
    private func processAccept(sender: ForwardSecurityContact, accept: ForwardSecurityDataAccept) throws {
        guard let session = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: accept.sessionID
        ) else {
            // Session not found, probably lost local data or old accept
            DDLogWarn("No DH session found for accepted session ID \(accept.sessionID) from \(sender.identity)")
            
            // Send "terminate" message for this session ID
            let terminate = ForwardSecurityDataTerminate(sessionID: accept.sessionID)
            sendMessageToContact(contact: sender, message: terminate)
            
            notifyListeners { listener in listener.sessionNotFound(sessionID: accept.sessionID, contact: sender) }
            return
        }
        
        try session.processAccept(
            peerEphemeralPublicKey: accept.ephemeralPublicKey,
            peerPublicKey: sender.publicKey,
            identityStore: identityStore
        )
        try dhSessionStore.storeDHSession(session: session)
        DDLogVerbose("Established 4DH session ID \(session.id) with \(sender.identity)")
        notifyListeners { listener in listener.initiatorSessionEstablished(session: session, contact: sender) }
    }
    
    private func processReject(sender: ForwardSecurityContact, reject: ForwardSecurityDataReject) throws {
        DDLogWarn("Received reject for DH session ID \(reject.sessionID) from \(sender.identity)")
        
        if try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: reject.sessionID
        ) != nil {
            // Discard session
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: reject.sessionID
            )
        }
        else {
            // Session not found, probably lost local data or old reject
            DDLogInfo("No DH session found for rejected session ID \(reject.sessionID) from \(sender.identity)")
        }
        
        notifyListeners { listener in listener.rejectReceived(
            sessionID: reject.sessionID,
            contact: sender,
            rejectedMessageID: reject.rejectedMessageID
        ) }
    }
    
    private func processMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) throws -> (AbstractMessage?, DHSession?) {
        let message = envelopeMessage.data as! ForwardSecurityDataMessage
        
        guard let session = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: message.sessionID
        ) else {
            // Session not found, probably lost local data or old message
            DDLogWarn("No DH session found for message in session ID \(message.sessionID) from \(sender.identity)")

            // Send reject message
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                rejectedMessageID: envelopeMessage.messageID,
                cause: .unknownSession
            )
            sendMessageToContact(contact: sender, message: reject)
            
            notifyListeners { listener in listener.sessionNotFound(sessionID: message.sessionID, contact: sender) }
            return (nil, nil)
        }

        // Obtain appropriate ratchet and turn to match the message's counter value
        let (ratchet, mode): (KDFRatchet?, ForwardSecurityMode) = try { switch message.type {
        case .twodh:
            return (session.peerRatchet2DH, .twoDH)
        case .fourdh:
            return (session.peerRatchet4DH, .fourDH)
        default:
            throw ForwardSecurityError.invalidMode
        }}()
        
        guard let ratchet else {
            // This can happen if the Accept message from our peer has been lost. In that case
            // they will think they are in 4DH mode, but we are still in 2DH.
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                rejectedMessageID: envelopeMessage.messageID,
                cause: .stateMismatch
            )
            sendMessageToContact(contact: sender, message: reject)
            notifyListeners { listener in listener.sessionBadDhState(sessionID: message.sessionID, contact: sender) }
            return (nil, nil)
        }

        // We should already be at the correct ratchet count since we increment it after
        // processing a message. If we have missed any messages, we will need to increment further.
        do {
            let numTurns = try ratchet.turnUntil(targetCounterValue: message.counter)
            if numTurns > 0 {
                notifyListeners { listener in
                    listener.messagesSkipped(sessionID: message.sessionID, contact: sender, numSkipped: Int(numTurns))
                }
            }
        }
        catch let error as RatchetRotationError {
            notifyListeners { listener in
                listener.messageOutOfOrder(sessionID: message.sessionID, contact: sender)
            }
            throw error
        }

        // Symmetrically decrypt message
        let ciphertext = message.message
        // A new key is used for each message, so the nonce can be zero
        let nonce = Data(count: Int(kNaClCryptoNonceSize))
        guard let plaintext = NaClCrypto.shared()
            .symmetricDecryptData(ciphertext, withKey: ratchet.currentEncryptionKey, nonce: nonce) else {
            
            // Send reject message
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                rejectedMessageID: envelopeMessage.messageID,
                cause: .stateMismatch
            )
            sendMessageToContact(contact: sender, message: reject)
            
            // Delete our own session as the peer will destroy this session as well
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: message.sessionID
            )
            
            notifyListeners { listener in listener.messageDecryptionFailed(
                sessionID: message.sessionID,
                contact: sender,
                failedMessageID: envelopeMessage.messageID
            ) }
            return (nil, nil)
        }
        
        DDLogVerbose(
            "Decrypted \(mode) message ID \(BytesUtility.toHexString(data: envelopeMessage.messageID)) from \(sender.identity) in session \(session.id)"
        )

        // Turn the ratchet once, as we will not need the current encryption key anymore and the
        // next message from the peer must have a ratchet count of at least one higher
        ratchet.turn()

        if mode == .fourDH {
            // If this was a 4DH message, then we should erase the 2DH peer ratchet, as we shall not
            // receive (or send) any further 2DH messages in this session
            if session.peerRatchet2DH != nil {
                session.discardPeerRatchet2DH()
            }

            // If this message was sent in what we also consider to be the "best" session (lowest ID),
            // then we can delete any other sessions.
            if let bestSession = try dhSessionStore.bestDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity
            ), bestSession.id == session.id {
                try dhSessionStore.deleteAllDHSessionsExcept(
                    myIdentity: identityStore.identity,
                    peerIdentity: sender.identity,
                    excludeSessionID: session.id,
                    fourDhOnly: false
                )
            }

            // If this was the first 4DH message in this session, inform the user
            if ratchet.counter == 2 {
                notifyListeners { listener in
                    listener.first4DhMessageReceived(sessionID: message.sessionID, contact: sender)
                }
            }
        }

        // Update ratchets in store (don't use storeDHSession(), as otherwise we
        // might overwrite the "my" ratchets if an outgoing message is being processed
        // for the same session at the same time)
        // TODO: Remove
        if !ThreemaEnvironment.lateSessionSave {
            try dhSessionStore.updateDHSessionRatchets(session: session, peer: true)
        }
        
        // Decode inner message and pass it to processor
        let innerMsg = MessageDecoder.decodeEncapsulated(plaintext, outer: envelopeMessage)
        innerMsg?.forwardSecurityMode = mode
        return (innerMsg, session)
    }
    
    /// This is the counterpart to `processEnvelopeMessage(sender:envelopeMessage)` storing the changes made to the ratchet after the message was processed
    /// This needs to be called after the message was stored in the DB as it cannot be decrypted anymore after that.
    /// This needs to be called before the next message starts processing because we only keep track of one partially processed session.
    /// - Parameters:
    ///   - sender: The sender of `envelopeMessage` and the sender of the last message that was processed
    ///   - envelopeMessage: The last `envelopeMessage` that was processed
    func updateRatchetCounters(
        session: DHSession
    ) throws {
        // Update ratchets in store (don't use storeDHSession(), as otherwise we
        // might overwrite the "my" ratchets if an outgoing message is being processed
        // for the same session at the same time)
        try dhSessionStore.updateDHSessionRatchets(session: session, peer: true)
    }
    
    private func processTerminate(sender: ForwardSecurityContact, terminate: ForwardSecurityDataTerminate) throws {
        DDLogVerbose("Terminating DH session ID \(terminate.sessionID) with \(sender.identity)")
        try dhSessionStore.deleteDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: terminate.sessionID
        )
        
        notifyListeners { listener in listener.sessionTerminated(sessionID: terminate.sessionID, contact: sender) }
    }
    
    private func sendMessageToContact(contact: ForwardSecurityContact, message: ForwardSecurityData) {
        let message = ForwardSecurityEnvelopeMessage(data: message)
        message.toIdentity = contact.identity
        messageSender.send(message: message)
    }
    
    private func notifyListeners(block: (ForwardSecurityStatusListener) -> Void) {
        for (id, listenerE) in listeners {
            guard let listener = listenerE.listener else {
                listeners.removeValue(forKey: id)
                continue
            }
            
            block(listener)
        }
    }
}
