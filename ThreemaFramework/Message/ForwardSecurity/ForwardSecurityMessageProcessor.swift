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

protocol ForwardSecurityMessageSenderProtocol {
    func send(message: AbstractMessage)
}

@objc class ForwardSecurityMessageProcessor: NSObject {
    private let dhSessionStore: DHSessionStoreProtocol
    private let identityStore: MyIdentityStoreProtocol
    private let messageSender: ForwardSecurityMessageSenderProtocol
    private let localSupportedVersionRange: CspE2eFs_VersionRange
    
    struct Listener {
        weak var listener: ForwardSecurityStatusListener?
    }

    private var listeners = [ObjectIdentifier: Listener]()
    
    init(
        dhSessionStore: DHSessionStoreProtocol,
        identityStore: MyIdentityStoreProtocol,
        messageSender: ForwardSecurityMessageSenderProtocol,
        localSupportedVersionRange: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion
    ) {
        self.dhSessionStore = dhSessionStore
        self.identityStore = identityStore
        self.messageSender = messageSender
        self.localSupportedVersionRange = localSupportedVersionRange
        
        super.init()
        
        self.dhSessionStore.errorHandler = self
    }
    
    func processEnvelopeMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) async throws -> (AbstractMessage?, DHSession?) {
        switch envelopeMessage.data {
        case let initT as ForwardSecurityDataInit:
            try await processInit(sender: sender, initT: initT)
        case let accept as ForwardSecurityDataAccept:
            try processAccept(sender: sender, accept: accept)
        case let reject as ForwardSecurityDataReject:
            try await processReject(sender: sender, reject: reject)
        case is ForwardSecurityDataMessage:
            return try processMessage(sender: sender, envelopeMessage: envelopeMessage)
        case let terminate as ForwardSecurityDataTerminate:
            try await processTerminate(sender: sender, terminate: terminate)
        default:
            assertionFailure("Unknown forward security message type")
        }
        return (nil, nil)
    }
    
    /// Wrapper for ObjC
    @objc func processEnvelopeMessageObjc(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage,
        errorP: NSErrorPointer
    ) async -> AbstractMessageAndPFSSession? {
        do {
            let (message, session) = try await processEnvelopeMessage(sender: sender, envelopeMessage: envelopeMessage)
            return AbstractMessageAndPFSSession(session: session, message: message)
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
                DDLogWarn(
                    "[ForwardSecurity] Rejecting FS message in session ID \(msg.sessionID) from \(sender.identity)"
                )
                
                let reject = try ForwardSecurityDataReject(
                    sessionID: msg.sessionID,
                    rejectedMessageID: envelopeMessage.messageID,
                    cause: .disabledByLocal
                )
                sendMessageToContact(contact: sender, message: reject)
            }
        }
        catch {
            // ignored
        }
    }
    
    /// Given that the contact supports forward security, determines whether we can send the given abstract message to
    /// this contact with the currently best session we have established
    /// Will throw an error iff an error occurs when attempting to find the best forward security session with this
    /// contact
    /// - Parameters:
    ///   - message: Message to check
    ///   - contact: Contact which supports forward security against whose best session we should check `message`
    /// - Returns: True if we can send this message as forward security encapsulated message and false otherwise
    func canSend(_ message: AbstractMessage, to contact: ForwardSecurityContact) throws -> Bool {
        guard let minimumRequiredForwardSecurityVersion = message.minimumRequiredForwardSecurityVersion else {
            DDLogNotice("[ForwardSecurity] Can't send message with forward security because it is not yet supported.")
            return false
        }
        
        guard minimumRequiredForwardSecurityVersion != .unspecified else {
            DDLogNotice("[ForwardSecurity] Can't send message with forward security because it is not yet supported.")
            return false
        }
        
        if case .UNRECOGNIZED = minimumRequiredForwardSecurityVersion {
            DDLogNotice("[ForwardSecurity] Can't send message with forward security because it is not yet supported")
            return false
        }

        guard let session = try dhSessionStore.bestDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: contact.identity
        ) else {
            DDLogNotice(
                "[ForwardSecurity] \(minimumRequiredForwardSecurityVersion.rawValue <= CspE2eFs_Version.v10.rawValue ? "Send" : "Don't send") message \(String(describing: message.type)) with minimum required version \(minimumRequiredForwardSecurityVersion) in session with assumed version \(CspE2eFs_Version.v10.rawValue)"
            )
            return minimumRequiredForwardSecurityVersion.rawValue <= CspE2eFs_Version.v10.rawValue
        }
        
        DDLogNotice(
            "[ForwardSecurity] \(minimumRequiredForwardSecurityVersion.rawValue <= session.outgoingAppliedVersion.rawValue ? "Send" : "Don't send") message \(String(describing: message.type)) with minimum required version \(minimumRequiredForwardSecurityVersion) in session with version \(session.outgoingAppliedVersion.rawValue)"
        )
        return minimumRequiredForwardSecurityVersion.rawValue <= session.outgoingAppliedVersion.rawValue
    }
    
    /// Wrap a message in a forward security envelope.
    ///
    /// - Returns: the wrapped `message`, optionally an auxiliary control message (`auxMessage`) that should be sent
    /// *before* the actual message, and the ID of a new session (if one had to be created)
    func makeMessage(
        contact: ForwardSecurityContact,
        innerMessage: AbstractMessage
    ) throws
        -> (
            auxMessage: ForwardSecurityEnvelopeMessage?,
            message: ForwardSecurityEnvelopeMessage,
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
            DDLogNotice("[ForwardSecurity] Starting new DH session ID \(newSession.id) with \(contact.identity)")
            notifyListeners { listener in listener.newSessionInitiated(session: newSession, contact: contact) }
            
            // Send init message
            let initMessage = try ForwardSecurityDataInit(
                sessionID: newSession.id,
                versionRange: ThreemaEnvironment.fsVersion,
                ephemeralPublicKey: newSession.myEphemeralPublicKey
            )
            initEnvelope = ForwardSecurityEnvelopeMessage(data: initMessage)
            initEnvelope?.toIdentity = contact.identity
            
            // Warn if we're trying to send something in an illegal state
            if try! newSession.state == .R20 {
                DDLogError("[ForwardSecurity] Encapsulating a message in R20 state is illegal")
            }
            
            // Check that the message type is supported in the current session
            try sanityCheckOrThrow(innerMessage, in: newSession)
            
            guard let requiredVersion = innerMessage.minimumRequiredForwardSecurityVersion else {
                // We check in `TaskExecution` that this never happens. This is just a final safeguard.
                DDLogError(
                    "[ForwardSecurity] Message \(innerMessage.messageID.hexEncodedString()) for \(String(describing: innerMessage.toIdentity)) of type \(innerMessage.type()) is not supported in FS session with negotiated version \(newSession.current4DHVersions)"
                )
                throw ForwardSecurityError.messageTypeNotSupported
            }
            
            if requiredVersion.rawValue > localSupportedVersionRange.min {
                // We check in `TaskExecution` that this never happens. This is just a final safeguard.
                DDLogError(
                    "[ForwardSecurity] Message \(innerMessage.messageID.hexEncodedString()) for \(String(describing: innerMessage.toIdentity)) of type \(innerMessage.type()) is not supported in FS session with negotiated version \(newSession.current4DHVersions)"
                )
                throw ForwardSecurityError.messageTypeNotSupported
            }
            
            return newSession
        }()
            
        DDLogNotice(
            "[ForwardSecurity] Make message of type \(innerMessage.type()) with id \(innerMessage.messageID.hexEncodedString()) for \(contact.identity) in session \(session.description)"
        )
        
        // Check that the message type is supported in the current session
        let appliedVersion = session.outgoingAppliedVersion
        try sanityCheckOrThrow(innerMessage, in: session)
        
        guard let requiredVersion = innerMessage.minimumRequiredForwardSecurityVersion else {
            // We check in `TaskExecution` that this never happens. This is just a final safeguard.
            DDLogError(
                "[ForwardSecurity] Message \(innerMessage.messageID.hexEncodedString()) for \(String(describing: innerMessage.toIdentity)) of type \(innerMessage.type()) is not supported in FS session with negotiated version \(session.current4DHVersions)"
            )
            throw ForwardSecurityError.messageTypeNotSupported
        }
        
        if requiredVersion.rawValue > appliedVersion.rawValue {
            // We check in `TaskExecution` that this never happens. This is just a final safeguard.
            DDLogError(
                "[ForwardSecurity] Message \(innerMessage.messageID.hexEncodedString()) for \(String(describing: innerMessage.toIdentity)) of type \(innerMessage.type()) is not supported in FS session with negotiated version \(session.current4DHVersions)"
            )
            throw ForwardSecurityError.messageTypeNotSupported
        }
    
        // Obtain encryption key from ratchet
        let (ratchetv, dhType, forwardSecurityMode): (
            KDFRatchet?,
            CspE2eFs_Encapsulated.DHType,
            ForwardSecurityMode
        ) = { if session.myRatchet4DH == nil {
            // 2DH mode
            return (
                session.myRatchet2DH,
                CspE2eFs_Encapsulated.DHType.twodh,
                .twoDH
            )
        }
        else {
            return (
                session.myRatchet4DH,
                CspE2eFs_Encapsulated.DHType.fourdh,
                .fourDH
            )
        }
        }()
        
        guard let ratchet = ratchetv else {
            throw ForwardSecurityError.noDHModeNegotiated
        }
        
        let currentKey = ratchet.currentEncryptionKey
        let counter = ratchet.counter
        ratchet.turn()
            
        // Update ratchets in store immediately to prevent key re-use with the same nonce (don't use storeDHSession(),
        // as otherwise we might overwrite the peer ratchets if an incoming message is being processed for the same
        // session at the same time)
        try dhSessionStore.updateDHSessionRatchets(session: session, peer: false)
            
        let sendAuxFailure = {
            // If sending the aux (init) message fails, delete the session again, as the peer won't
            // know about it, and we should create a new session with a new init when we retry.
            if let newSessionID {
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
            if let body = innerMessage.body() {
                plaintext += body
            }
        }
        
        // A new key is used for each message, so the nonce can be zero
        let nonce = Data(count: Int(kNaClCryptoNonceSize))
        let ciphertext = NaClCrypto.shared().symmetricEncryptData(plaintext, withKey: currentKey, nonce: nonce)!
            
        let dataMessage = ForwardSecurityDataMessage(
            sessionID: session.id,
            type: dhType,
            offeredVersion: session.outgoingOfferedVersion,
            appliedVersion: appliedVersion,
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

        return (initEnvelope, envelope, sendAuxFailure)
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
    
    private func processInit(sender: ForwardSecurityContact, initT: ForwardSecurityDataInit) async throws {
        DDLogNotice(
            "[ForwardSecurity] Received init {sessionID=\(initT.sessionID),versionRange=\(initT.versionRange)} from \(sender.identity)"
        )
        
        if try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: initT.sessionID
        ) != nil {
            // Silently discard init message for existing session
            DDLogNotice(
                "[ForwardSecurity] Silently discard init with session ID \(initT.sessionID) from \(sender.identity)"
            )
            return
        }
        
        // The initiator will only send an Init if it does not have an existing session. This means
        // that any 4DH sessions that we have stored for this contact are obsolete and should be deleted.
        // We will keep 2DH sessions (which will have been initiated by us), as otherwise messages may
        // be lost during Init race conditions.
        let existingSessionPreempted = try dhSessionStore.deleteAllDHSessionsExcept(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            excludeSessionID: initT.sessionID,
            fourDhOnly: true
        ) > 0
        
        if await !hasForwardSecuritySupport(sender) {
            _ = await checkFSFeatureMask(for: sender)
        }
        
        // Create and send accept in case the contact supports forward security
        guard await hasForwardSecuritySupport(sender) else {
            DDLogNotice("[ForwardSecurity] Terminate sessions with \(sender.identity) because it is not supported.")
            
            // We may still have a FS session to report that was terminated
            if existingSessionPreempted {
                notifyListeners { listener in
                    listener.sessionTerminated(
                        sessionID: nil,
                        contact: sender,
                        sessionUnknown: false,
                        hasForwardSecuritySupport: false
                    )
                }
            }
            
            // If the contact does not have the feature mask set correctly, we assume that the
            // `Init` is stale, then silently terminate this session.
            let terminate = ForwardSecurityDataTerminate(sessionID: initT.sessionID, cause: .disabledByRemote)
            sendMessageToContact(contact: sender, message: terminate)
            
            // The feature mask update subroutine should have already detected the downgrade and
            // removed any existing FS sessions. But we'll do it here again anyways for good
            // measures and because the remote may be dishonest about its feature capabilities.
            
            try ForwardSecuritySessionTerminator().terminateAllSessions(with: sender.identity, cause: .disabledByRemote)
            return
        }
        
        // Only create a new session from the init if the contact supports forward security
        let session = try DHSession(
            id: initT.sessionID,
            peerEphemeralPublicKey: initT.ephemeralPublicKey,
            peerIdentity: sender.identity,
            peerPublicKey: sender.publicKey,
            version: initT.versionRange,
            identityStore: identityStore
        )
        try dhSessionStore.storeDHSession(session: session)
        DDLogNotice("[ForwardSecurity] Responding to new DH session ID \(session.id) request from \(sender.identity)")
        notifyListeners { listener in listener.responderSessionEstablished(
            session: session,
            contact: sender,
            existingSessionPreempted: existingSessionPreempted
        ) }
        
        DDLogNotice(
            "[ForwardSecurity] Create and send accept with version \(ThreemaEnvironment.fsVersion) for init with session ID \(initT.sessionID) from \(sender.identity)"
        )

        // Create and send accept
        let accept = try ForwardSecurityDataAccept(
            sessionID: initT.sessionID,
            version: ThreemaEnvironment.fsVersion,
            ephemeralPublicKey: session.myEphemeralPublicKey
        )
        sendMessageToContact(contact: sender, message: accept)
    }
    
    private func checkFSFeatureMask(for contact: ForwardSecurityContact) async -> Bool {
        await listeners.compactMap { $0.value.listener as? ForwardSecurityStatusSender }.first?
            .updateFeatureMask(for: contact) ?? true
    }
    
    private func hasForwardSecuritySupport(_ contact: ForwardSecurityContact) async -> Bool {
        await listeners.compactMap { $0.value.listener as? ForwardSecurityStatusSender }.first?
            .hasForwardSecuritySupport(contact) ?? true
    }
    
    private func processAccept(sender: ForwardSecurityContact, accept: ForwardSecurityDataAccept) throws {
        DDLogNotice(
            "[ForwardSecurity] Received accept {sessionID=\(accept.sessionID),versionRange=\(accept.version)} from \(sender.identity)"
        )
        
        guard let session = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: accept.sessionID
        ) else {
            // Session not found, probably lost local data or old accept
            DDLogWarn(
                "[ForwardSecurity] No DH session found for accepted session ID \(accept.sessionID) from \(sender.identity)"
            )
            
            // Send "terminate" message for this session ID
            let terminate = ForwardSecurityDataTerminate(sessionID: accept.sessionID, cause: .unknownSession)
            sendMessageToContact(contact: sender, message: terminate)
            
            notifyListeners { listener in listener.sessionNotFound(sessionID: accept.sessionID, contact: sender) }
            return
        }
        
        try session.processAccept(
            peerEphemeralPublicKey: accept.ephemeralPublicKey,
            peerPublicKey: sender.publicKey,
            peerSupportedVersionRange: accept.version,
            identityStore: identityStore
        )
        
        try dhSessionStore.storeDHSession(session: session)
        DDLogNotice(
            "[ForwardSecurity] Established 4DH session ID \(session.id) with \(sender.identity), negotiated version: \(session.current4DHVersions)"
        )
        notifyListeners { listener in listener.initiatorSessionEstablished(session: session, contact: sender) }
    }
    
    private func processReject(sender: ForwardSecurityContact, reject: ForwardSecurityDataReject) async throws {
        DDLogWarn(
            "[ForwardSecurity] Received reject for DH session ID \(reject.sessionID) from \(sender.identity) cause \(reject.cause)"
        )
        
        let sessionExists = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: reject.sessionID
        ) != nil
        
        if sessionExists {
            // Discard session
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: reject.sessionID
            )
            DDLogNotice("[ForwardSecurity] Process reject, session ID \(reject.sessionID) from \(sender.identity)")
        }
        else {
            // Session not found, probably lost local data or old reject
            DDLogNotice("No DH session found for rejected session ID \(reject.sessionID) from \(sender.identity)")
        }
        
        // Refresh feature mask now, in case contact downgraded to a build without PFS
        let hasForwardSecuritySupport = await checkFSFeatureMask(for: sender)
        
        // TODO: (IOS-3949) Is this nil for session correct? I guess were deleting it above?
        notifyListeners { listener in listener.rejectReceived(
            sessionID: reject.sessionID,
            contact: sender,
            session: nil,
            rejectedMessageID: reject.rejectedMessageID,
            rejectCause: reject.cause,
            hasForwardSecuritySupport: hasForwardSecuritySupport
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
            DDLogWarn(
                "[ForwardSecurity] No DH session found for message \(envelopeMessage.getMessageIDString() ?? "Missing Message ID") in session ID \(message.sessionID) from \(sender.identity)"
            )

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
        
        // Validate offered and applied version
        var processedVersion: ProcessedVersions? = nil
        do {
            processedVersion = try session.processIncomingMessageVersion(message: message)
        }
        catch let RejectMessageError.rejectMessageError(description: description) {
            DDLogNotice("[ForwardSecurity] ProcessMessaged failed with error: \(description)")
            DDLogNotice("[ForwardSecurity] Message rejected by session validator, `Reject` and terminate the session")
            
            // Message rejected by session validator, `Reject` and terminate the session
            let reject = try ForwardSecurityDataReject(
                sessionID: session.id,
                rejectedMessageID: envelopeMessage.messageID,
                cause: .stateMismatch
            )
            sendMessageToContact(contact: sender, message: reject)
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: session.id
            )
            
            // TODO: Should we supply an error cause for the UI here? Otherwise this looks as if the remote willingly terminated.
            notifyListeners { listener in listener.sessionTerminated(
                sessionID: session.id,
                contact: sender,
                sessionUnknown: false,
                hasForwardSecuritySupport: true
            ) }
            
            return (nil, nil)
        }
        catch {
            fatalError(
                "[ForwardSecurity] `processIncomingMessageVersion` may only throw errors of kind `RejectMessageError`"
            )
        }
        
        guard let processedVersion else {
            fatalError(
                "[ForwardSecurity] If processedVersion is nil here `DHSession.processIncomingMessageVersion` has thrown an error which was handled above."
            )
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
            // they will think they are in 4DH mode, but we are still in 2DH. `Reject` and terminate the session.
            
            DDLogError(
                "[ForwardSecurity] Rejecting message in session \(session.description) with \(sender.identity), cause: DH type mismatch (mode={\(mode)})"
            )
            
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
            
            // TODO: Should we supply an error cause for the UI here? Otherwise this looks as if the remote willingly terminated.
            notifyListeners { listener in
                listener.sessionTerminated(
                    sessionID: session.id,
                    contact: sender,
                    sessionUnknown: false,
                    hasForwardSecuritySupport: true
                )
            }
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
                listener.messageOutOfOrder(
                    sessionID: message.sessionID,
                    contact: sender,
                    messageID: envelopeMessage.messageID
                )
            }
            throw error
        }

        // Symmetrically decrypt message
        let ciphertext = message.message
        // A new key is used for each message, so the nonce can be zero
        let nonce = Data(count: Int(kNaClCryptoNonceSize))
        guard let plaintext = NaClCrypto.shared().symmetricDecryptData(
            ciphertext,
            withKey: ratchet.currentEncryptionKey,
            nonce: nonce
        ) else {
            DDLogError(
                "[ForwardSecurity] Rejecting message in session \(session) with \(sender.identity), cause: Message decryption failed (message-id={\(envelopeMessage.messageID.hexString)}"
            )
            
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
            
            return (nil, nil)
        }
        
        DDLogNotice(
            "[ForwardSecurity] Decapsulated message from {\(sender.identity)} (message-id={\(envelopeMessage.messageID.hexString)}, mode={\(mode)}, session={\(session.description)}, offered-version={\(processedVersion)}, applied-version={\(message.appliedVersion)})"
        )
        
        // Commit the updated negotiated version
        let updatedVersionsSnapshot = session.commitVersion(processedVersions: processedVersion)
        if let updatedVersionsSnapshot {
            notifyListeners { statusListener in
                statusListener.versionsUpdated(
                    in: session,
                    versionUpdatedSnapshot: updatedVersionsSnapshot,
                    contact: sender
                )
            }
        }

        // Turn the ratchet once, as we will not need the current encryption key anymore and the
        // next message from the peer must have a ratchet count of at least one higher
        ratchet.turn()

        if mode == .fourDH {
            // If this was a 4DH message, then we should erase the 2DH peer ratchet, as we shall not
            // receive (or send) any further 2DH messages in this session
            // Note that this is also necessary to determine the correct session state.
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

            // If this was the first 4DH message in this session, inform the user (only required in version 1.0, this is
            // checked in `first4DhMessageReceived`).
            if ratchet.counter == 2 {
                notifyListeners { listener in
                    listener.first4DhMessageReceived(session: session, contact: sender)
                }
            }
        }
        
        // Decode inner message and pass it to processor
        let innerMsg = try MessageDecoder.decode(
            encapsulated: plaintext,
            with: envelopeMessage,
            for: processedVersion.appliedVersion
        )
        innerMsg?.forwardSecurityMode = mode
        return (innerMsg, session)
    }
    
    /// This is the counterpart to `processEnvelopeMessage(sender:envelopeMessage)` storing the changes made to the
    /// ratchet after the message was processed
    /// This needs to be called after the message was stored in the DB as it cannot be decrypted anymore after that.
    /// This needs to be called before the next message starts processing because we only keep track of one partially
    /// processed session.
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
    
    @objc func warnIfMessageWithoutForwardSecurityReceived(
        for message: AbstractMessage,
        from sender: ForwardSecurityContact
    ) {
        do {
            let bestSession = try dhSessionStore.bestDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: message.fromIdentity
            )
            
            guard let bestSession else {
                // If we do not have a session we don't need to do anything
                DDLogNotice("[ForwardSecurity] \(#function): We do not have a session. Don't warn.")
                return
            }
            
            let minimumVersion = message.minimumRequiredForwardSecurityVersion()
            
            DDLogNotice(
                "[ForwardSecurity] \(#function): \(minimumVersion != .unspecified && minimumVersion.rawValue <= bestSession.minimumIncomingAppliedVersion.rawValue ? "maybe warn" : "don't warn") Checking message minimum version \(minimumVersion) against session \(bestSession.description) with minimumIncomingAppliedVersion \(bestSession.minimumIncomingAppliedVersion)"
            )
            
            if minimumVersion != .unspecified,
               minimumVersion.rawValue <= bestSession.minimumIncomingAppliedVersion.rawValue {
                Task {
                    let hasForwardSecuritySupport = await hasForwardSecuritySupport(sender)
                    
                    // TODO(ANDR-2452): Remove this feature mask update when enough clients have updated
                    // Check whether this contact still supports forward security when receiving a message without
                    // forward
                    // security.
                    if hasForwardSecuritySupport {
                        _ = await checkFSFeatureMask(for: sender)
                    }
                    
                    if hasForwardSecuritySupport {
                        notifyListeners { listener in
                            listener
                                .messageWithoutFSReceived(
                                    in: bestSession,
                                    contactIdentity: message.fromIdentity,
                                    message: message
                                )
                        }
                    }
                    else {
                        DDLogNotice("\(#function): Contact has downgraded to an unsupported version. Don't warn.")
                    }
                }
            }
        }
        catch {
            DDLogError("Could not get best session: \(error)")
        }
    }
    
    private func processTerminate(
        sender: ForwardSecurityContact,
        terminate: ForwardSecurityDataTerminate
    ) async throws {
        DDLogNotice(
            "Terminating DH session ID \(terminate.sessionID) with \(sender.identity), cause: \(terminate.cause)"
        )
        
        let sessionExists = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: terminate.sessionID
        ) != nil
        if !sessionExists {
            DDLogNotice("We do not have a DH session ID \(terminate.sessionID) with \(sender.identity)")
        }
        else {
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: terminate.sessionID
            )
        }
        
        /// Refresh feature mask now, in case contact downgraded to a build without PFS
        ///
        /// We're waiting for the feature mask check to complete here. This is not great since we're stopping message
        /// processing.
        /// But we need the check to complete before deleting the session since we need to know if the contact has
        /// downgraded its feature mask.
        /// There is a similar check in `ContactEntity.h` which would result in a duplicate system message if we didn't
        /// delete the session above.
        /// (This might still lead to duplicate status messages if we have other sessions than the one we're deleting
        /// above. But we expect this case to be rare.)
        ///
        /// Improvements for this are tracked as part of SE-267
        let hasForwardSecuritySupport = await checkFSFeatureMask(for: sender)
        
        notifyListeners { listener in listener.sessionTerminated(
            sessionID: terminate.sessionID,
            contact: sender,
            sessionUnknown: !sessionExists,
            hasForwardSecuritySupport: hasForwardSecuritySupport
        ) }
    }
    
    private func sendMessageToContact(contact: ForwardSecurityContact, message: ForwardSecurityData) {
        let message = ForwardSecurityEnvelopeMessage(data: message)
        message.toIdentity = contact.identity
        messageSender.send(message: message)
    }
    
    private func sendMessageToContact(identity: String, message: ForwardSecurityData) {
        let message = ForwardSecurityEnvelopeMessage(data: message)
        message.toIdentity = identity
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
    
    private func sanityCheckOrThrow(_ message: AbstractMessage, in session: DHSession) throws {
        guard let requiredVersion = message.minimumRequiredForwardSecurityVersion else {
            // We check in `TaskExecution` that this never happens. This is just a final safeguard.
            DDLogError(
                "Message \(message.messageID.hexEncodedString()) for \(String(describing: message.toIdentity)) of type \(message.type()) is not supported in FS session with negotiated version \(session.current4DHVersions?.description ?? "nil")"
            )
            throw ForwardSecurityError.messageTypeNotSupported
        }
        
        if requiredVersion == .unspecified {
            // We check in `TaskExecution` that this never happens. This is just a final safeguard.
            DDLogError(
                "Message \(message.messageID.hexEncodedString()) for \(String(describing: message.toIdentity)) of type \(message.type()) is not supported in FS session with negotiated version \(session.current4DHVersions?.description ?? "nil")"
            )
            throw ForwardSecurityError.messageTypeNotSupported
        }
        
        if case .UNRECOGNIZED = requiredVersion {
            // We check in `TaskExecution` that this never happens. This is just a final safeguard.
            DDLogError(
                "Message \(message.messageID.hexEncodedString()) for \(String(describing: message.toIdentity)) of type \(message.type()) is not supported in FS session with negotiated version \(session.current4DHVersions?.description ?? "nil")"
            )
            throw ForwardSecurityError.messageTypeNotSupported
        }
    }
}

// MARK: - SQLDHSessionStoreErrorHandler

extension ForwardSecurityMessageProcessor: SQLDHSessionStoreErrorHandler {
    func handleDHSessionIllegalStateError(sessionID: DHSessionID, peerIdentity: String) {
        let terminate = ForwardSecurityDataTerminate(sessionID: sessionID, cause: .reset)
        sendMessageToContact(identity: peerIdentity, message: terminate)
        notifyListeners { listener in
            listener.illegalSessionState(identity: peerIdentity, sessionID: sessionID)
        }
    }
}
