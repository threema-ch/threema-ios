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

import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaProtocols

@objc class ForwardSecurityMessageProcessor: NSObject {
    private let dhSessionStore: DHSessionStoreProtocol
    private let identityStore: MyIdentityStoreProtocol
    private let messageSender: MessageSenderProtocol
    private let taskManager: TaskManagerProtocol
    private let localSupportedVersionRange: CspE2eFs_VersionRange
    
    struct Listener {
        weak var listener: ForwardSecurityStatusListener?
    }

    private var listeners = [ObjectIdentifier: Listener]()
    
    init(
        dhSessionStore: DHSessionStoreProtocol,
        identityStore: MyIdentityStoreProtocol,
        messageSender: MessageSenderProtocol,
        taskManager: TaskManagerProtocol,
        localSupportedVersionRange: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion
    ) {
        self.dhSessionStore = dhSessionStore
        self.identityStore = identityStore
        self.messageSender = messageSender
        self.taskManager = taskManager
        self.localSupportedVersionRange = localSupportedVersionRange
        
        super.init()
        
        self.dhSessionStore.errorHandler = self
    }
    
    /// Process an incoming envelope message
    ///
    /// - Parameters:
    ///   - sender: Sender of message
    ///   - envelopeMessage: Envelope message
    /// - Returns: Decapsulated message and FS info about the message if message was not rejected or an auxiliary
    ///            message, `(nil, nil)` otherwise (i.e. for also for successfully processed auxiliary messages)
    func processEnvelopeMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) async throws -> (AbstractMessage?, FSMessageInfo?) {
        
        // Except for actual messages we just return `(nil, nil)` on success. This could probably be improved if the
        // return types are rethought and maybe the session could be returned for some of the messages.
        
        switch envelopeMessage.data {
            
        case let initT as ForwardSecurityDataInit:
            try await processInit(sender: sender, initT: initT)
            return (nil, nil)
            
        case let accept as ForwardSecurityDataAccept:
            try processAccept(sender: sender, accept: accept)
            return (nil, nil)
            
        case let reject as ForwardSecurityDataReject:
            try await processReject(sender: sender, reject: reject)
            return (nil, nil)
            
        case is ForwardSecurityDataMessage:
            return try processMessage(sender: sender, envelopeMessage: envelopeMessage)
            
        case let terminate as ForwardSecurityDataTerminate:
            try await processTerminate(sender: sender, terminate: terminate)
            return (nil, nil)
            
        default:
            assertionFailure("Unknown forward security message type")
        }
        
        throw ForwardSecurityError.unknownEnvelope
    }
    
    /// Wrapper for ObjC (see `processEnvelopeMessage(sender:envelopeMessage:)` for details)
    @objc func processEnvelopeMessageObjC(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) async throws -> AbstractMessageAndFSMessageInfo? {
        let (message, fsMessageInfo) = try await processEnvelopeMessage(
            sender: sender,
            envelopeMessage: envelopeMessage
        )
        return AbstractMessageAndFSMessageInfo(message: message, fsMessageInfo: fsMessageInfo)
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
                    messageID: envelopeMessage.messageID,
                    groupIdentity: msg.groupIdentity,
                    cause: .disabledByLocal
                )
                sendMessageToContact(contact: sender, message: reject)
            }
        }
        catch {
            // ignored
        }
    }
    
    /// Encapsulate message with FS, if possible
    ///
    /// After successfully sending the messages and one of them was an FS message `newSessionCommitted` and
    /// `lastMessageSent` of the session should be updated an persisted.
    ///
    /// Protocol: This implements the _FS Encapsulation Steps_.
    ///
    /// Our implementation differs in two ways:
    /// 1. We don't return an arbitrary array of outer messages, but always a `message` and if needed an auxiliary
    ///    message (`auxMessage`) that needs to be send before the actual message
    /// 2. We immediately store the session, but set the `newSessionCommitted` to `false`. This is needed because with
    ///    two queues the session might already receive and process an `Accept` before the actual `message` is sent.
    ///    Additionally we update and store the ratchet just before we use the current key to prevent key-reuse with the
    ///    same nonce.
    ///
    /// - Parameters:
    ///   - receiver: Receiver of message
    ///   - innerMessage: Actual message that should be send and might be encapsulated in an FS message
    ///                   (this cannot be a `ForwardSecurityEnvelopeMessage`)
    ///
    /// - Returns: Optionally an auxiliary message (`auxMessage`) that should be sent *before* the actual message and
    ///            the `innerMessage` that might be wrapped in a FS envelope (see _FS Encapsulation Steps_ for details)
    func makeMessage(
        receiver: ForwardSecurityContact,
        innerMessage: AbstractMessage
    ) throws -> (
        auxMessage: ForwardSecurityEnvelopeMessage?,
        outerMessage: AbstractMessage
    ) {
        // FS Encapsulation Steps (1.)
        // 1. Let `inner-type` be any message type except `0xa0` and `inner-message` be
        //    the associated data of the message. Let `receiver` be the receiver of the
        //    message (which is assumed to support FS).
        guard !(innerMessage is ForwardSecurityEnvelopeMessage) else {
            DDLogError("[ForwardSecurity] Inner message is already a FS message")
            assertionFailure()
            throw ForwardSecurityError.messageTypeNotSupported
        }
        
        var auxMessage: ForwardSecurityEnvelopeMessage?
        let outerMessage: AbstractMessage
        
        var initCreated = false
        
        // FS Encapsulation Steps (4.)
        // 4. If `session` is undefined, initiate a new `L20` session and set `session`
        //    to the newly created session. Append the `Init` message for `session` to
        //    `outer-messages` with type `0xa0`.
        
        // If no session exists create a new one
        let session = try dhSessionStore.bestDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: receiver.identity
        ) ?? newSession(with: receiver)

        // Prepare an init message if none was sent for this session
        // This happens if a new session was created or if something during the sending of an `Init` fails. It is safe
        // to send an `Init` for the same session again.
        if !session.newSessionCommitted {
            auxMessage = try makeInitMessage(for: session)
            initCreated = true
        }
        
        // FS Encapsulation Steps (5.)
        // 5. If `inner-type` is not eligible to be encapsulated by `session`:
        if !canSend(innerMessage, in: session) {
            // FS Encapsulation Steps (5.1.)
            //    1. If `session` is not a newly created session and the last time a message
            //       of type `0xa0` has been sent to `receiver` is more than 24h ago, create
            //       an `Encapsulated` message using `session` from inner type `0xfc`
            //       (_empty_) and append the encrypted and encoded result to
            //       `outer-messages` with type `0xa0`.
            if !initCreated,
               // If no date is set we assume 1.1.1970 as last message sent date and let this be `true`
               (session.lastMessageSent ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(60 * 60 * 24) < .now {
                
                assert(auxMessage == nil, "No aux message should already be set")
                
                auxMessage = try makeEmptyMessage(for: session)
            }
            
            // FS Encapsulation Steps (5.2.)
            //    2. Append `inner-message` as a non-encapsulated message to
            //       `outer-messages` with type `inner-type`.
            outerMessage = innerMessage
        }
        // FS Encapsulation Steps (6.)
        // 6. If `inner-type` is eligible to be encapsulated by `session`, create an
        //    `Encapsulated` message using `session` from `inner-type` and
        //    `inner-message` and append the encrypted and encoded result to
        //    `outer-messages` with type `0xa0`.
        else {
            outerMessage = try encapsulate(innerMessage, in: session)
        }

        return (auxMessage, outerMessage)
    }
    
    /// Crate a new session if there doesn't exist one with this contact and create an `Init` message for it
    /// - Parameter contact: Contact to establish session with
    /// - Returns: `Init` message for new session
    /// - Throws: `ForwardSecurityError.existingSession` if a session already exists with `contact` and other errors if
    /// session or message creation fails.
    func makeNewSession(
        with contact: ForwardSecurityContact
    ) throws -> ForwardSecurityEnvelopeMessage {
        // Don't create a new session if there already is one
        guard try dhSessionStore.bestDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: contact.identity
        ) == nil else {
            throw ForwardSecurityError.existingSession
        }
        
        let newSession = try newSession(with: contact)
        let initMessage = try makeInitMessage(for: newSession)
        
        return initMessage
    }
    
    /// Create an `Init` message for `session`
    /// - Parameter session: Session to create `Init` message for
    /// - Returns: `Init` message
    func makeInitMessage(for session: DHSession) throws -> ForwardSecurityEnvelopeMessage {
        DDLogNotice("[ForwardSecrecy] Make init message for \(session)")
        
        let initMessage = try ForwardSecurityDataInit(
            sessionID: session.id,
            versionRange: localSupportedVersionRange,
            ephemeralPublicKey: session.myEphemeralPublicKey
        )
        
        let encapsulatedInitMessage = ForwardSecurityEnvelopeMessage(data: initMessage)
        encapsulatedInitMessage.toIdentity = session.peerIdentity
        
        return encapsulatedInitMessage
    }
    
    /// Create an a FS message containing an `empty` message
    /// - Parameter session: Session to use to encapsulate empty message (own ratchets will be updated)
    /// - Returns: Encapsulated `empty` message
    func makeEmptyMessage(
        for session: DHSession
    ) throws -> ForwardSecurityEnvelopeMessage {
        DDLogNotice("[ForwardSecrecy] Make empty message for \(session)")
        
        let emptyMessage = BoxEmptyMessage()
        emptyMessage.toIdentity = session.peerIdentity
        
        return try encapsulate(emptyMessage, in: session)
    }
    
    @objc func hasContactUsedForwardSecurity(contact: ForwardSecurityContact) -> Bool {
        guard let myIdentity = identityStore.identity else {
            return false
        }
        
        do {
            if let bestSession = try dhSessionStore.bestDHSession(
                myIdentity: myIdentity,
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
    
    // MARK: - Private functions
    
    // MARK: Process helper
    
    /// Process a `ForwardSecurityDataInit` message
    /// - Parameters:
    ///   - sender: Sender of message
    ///   - initT: Init message
    private func processInit(sender: ForwardSecurityContact, initT: ForwardSecurityDataInit) async throws {
        DDLogNotice(
            "[ForwardSecurity] Received init (sessionID=\(initT.sessionID), versionRange=\(initT.versionRange)) from \(sender.identity)"
        )
        
        if try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: initT.sessionID
        ) != nil {
            // Silently discard init message for existing session
            DDLogWarn(
                "[ForwardSecurity] Silently discard init with session ID \(initT.sessionID) from \(sender.identity) for existing session"
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
            DDLogWarn("[ForwardSecurity] Terminate sessions with \(sender.identity) because FS is not supported.")
            
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
            
            _ = try ForwardSecuritySessionTerminator().terminateAllSessions(
                with: sender.identity,
                cause: .disabledByRemote
            )
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
        
        // Accept needs to be sent directly (as stated in the protocol) and not in a new task. Otherwise this might lead
        // to an invalide state at the sender. (IOS-5241)
        let message = ForwardSecurityEnvelopeMessage(data: accept)
        message.toIdentity = sender.identity
        let task = TaskDefinitionSendAbstractMessage(message: message)
        try await taskManager.executeSubTask(taskDefinition: task)
    }
    
    private func checkFSFeatureMask(for contact: ForwardSecurityContact) async -> Bool {
        await listeners.compactMap { $0.value.listener as? ForwardSecurityStatusSender }.first?
            .updateFeatureMask(for: contact) ?? true
    }
    
    private func hasForwardSecuritySupport(_ contact: ForwardSecurityContact) async -> Bool {
        await listeners.compactMap { $0.value.listener as? ForwardSecurityStatusSender }.first?
            .hasForwardSecuritySupport(contact) ?? true
    }
    
    /// Process a `ForwardSecurityDataAccept` message
    /// - Parameters:
    ///   - sender: Sender of message
    ///   - accept: Accept message
    private func processAccept(sender: ForwardSecurityContact, accept: ForwardSecurityDataAccept) throws {
        DDLogNotice(
            "[ForwardSecurity] Received accept (sessionID=\(accept.sessionID), versionRange=\(accept.version)) from \(sender.identity)"
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
            "[ForwardSecurity] Established 4DH \(session)"
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
            DDLogNotice(
                "[ForwardSecurity] No DH session found for rejected session ID \(reject.sessionID) from \(sender.identity)"
            )
        }
        
        // Refresh feature mask now, in case contact downgraded to a build without PFS
        let hasForwardSecuritySupport = await checkFSFeatureMask(for: sender)
        
        // TODO: (IOS-3949) Is this nil for session correct? I guess were deleting it above?
        notifyListeners { listener in listener.rejectReceived(
            sessionID: reject.sessionID,
            contact: sender,
            session: nil,
            rejectedMessageID: reject.messageID,
            groupIdentity: reject.groupIdentity,
            rejectCause: reject.cause,
            hasForwardSecuritySupport: hasForwardSecuritySupport
        ) }
    }
    
    /// Process a "normal" Forward Security message (`ForwardSecurityDataMessage`)
    /// - Parameters:
    ///   - sender: Sender of message
    ///   - envelopeMessage: Envelope message
    /// - Returns: Message and FS info about the message if message was not rejected, `(nil, nil)` otherwise
    private func processMessage(
        sender: ForwardSecurityContact,
        envelopeMessage: ForwardSecurityEnvelopeMessage
    ) throws -> (AbstractMessage?, FSMessageInfo?) {
        let message = envelopeMessage.data as! ForwardSecurityDataMessage
        
        // 2. Let `session` be the associated session (if any).
        guard let session = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: message.sessionID
        ) else {
            // 3. If `session` is not defined, `Reject` the message with a `UNKNOWN_SESSION`
            //    and abort these steps.
            
            // Session not found, probably lost local data or old message
            DDLogWarn(
                "[ForwardSecurity] No DH session found for message (message-id=\(envelopeMessage.messageID.hexString)) in session with ID \(message.sessionID) from \(sender.identity)"
            )

            // Send reject message
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                messageID: envelopeMessage.messageID,
                groupIdentity: message.groupIdentity,
                cause: .unknownSession
            )
            sendMessageToContact(contact: sender, message: reject)
            
            notifyListeners {
                $0.sessionNotFound(sessionID: message.sessionID, contact: sender)
            }
            
            return (nil, nil)
        }
        
        // Validate offered and applied version
        var processedVersion: ProcessedVersions? = nil
        do {
            processedVersion = try session.processIncomingMessageVersion(message: message)
        }
        catch let RejectMessageError.rejectMessageError(description: description) {
            DDLogError(
                "[ForwardSecurity] Message rejected by session validator. `Reject` (message-id=\(envelopeMessage.messageID.hexString)) and terminate \(session): \(description)"
            )
            
            // Message rejected by session validator, `Reject` and terminate the session
            let reject = try ForwardSecurityDataReject(
                sessionID: session.id,
                messageID: envelopeMessage.messageID,
                groupIdentity: message.groupIdentity,
                cause: .stateMismatch
            )
            sendMessageToContact(contact: sender, message: reject)
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: session.id
            )
            
            // TODO: Should we supply an error cause for the UI here? Otherwise this looks as if the remote willingly terminated.
            notifyListeners {
                $0.sessionTerminated(
                    sessionID: session.id,
                    contact: sender,
                    sessionUnknown: false,
                    hasForwardSecuritySupport: true
                )
            }
            
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
                "[ForwardSecurity] DH type mismatch (mode=\(mode)). Rejecting message (message-id=\(envelopeMessage.messageID.hexString)) in \(session)"
            )
            
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                messageID: envelopeMessage.messageID,
                groupIdentity: message.groupIdentity,
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
            notifyListeners {
                $0.sessionTerminated(
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
                notifyListeners {
                    $0.messagesSkipped(sessionID: message.sessionID, contact: sender, numSkipped: Int(numTurns))
                }
            }
        }
        catch let error as RatchetRotationError {
            notifyListeners {
                $0.messageOutOfOrder(
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
                "[ForwardSecurity] Message decryption failed (message-id=\(envelopeMessage.messageID.hexString)). Rejecting message in \(session)"
            )
            
            // Send reject message
            let reject = try ForwardSecurityDataReject(
                sessionID: message.sessionID,
                messageID: envelopeMessage.messageID,
                groupIdentity: message.groupIdentity,
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
            "[ForwardSecurity] Decapsulating message (message-id=\(envelopeMessage.messageID.hexString)), in \(session), offered-version={\(processedVersion)}, applied-version=\(message.appliedVersion)"
        )
        
        // Prepare to commit the updated negotiated version
        let updateVersionsIfNeeded = { () -> Bool in
            let updatedVersionsSnapshot = session.commitVersion(processedVersions: processedVersion)
            
            if let updatedVersionsSnapshot {
                self.notifyListeners {
                    $0.versionsUpdated(
                        in: session,
                        versionUpdatedSnapshot: updatedVersionsSnapshot,
                        contact: sender
                    )
                }
                
                return true
            }
            
            return false
        }

        // Turn the ratchet once, as we will not need the current encryption key anymore and the
        // next message from the peer must have a ratchet count of at least one higher
        ratchet.turn()
        
        // The ratchet is persisted in `TaskExecutionReceiveMessage` after the message is fully processed

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
                DDLogVerbose(
                    "[ForwardSecurity] Best session is the same as used session. Delete other sessions if there are any. \(session)"
                )
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
        
        let fsMessageInfo = FSMessageInfo(session: session, updateVersionsIfNeeded: updateVersionsIfNeeded)
        
        return (innerMsg, fsMessageInfo)
    }
    
    /// Update session peer ratchet counters and versions
    ///
    /// This is the counterpart to `processEnvelopeMessage(sender:envelopeMessage)` storing the changes made to the
    /// ratchet after the message was processed.
    /// This needs to be called after the message was stored in the DB as it cannot be decrypted anymore after that.
    /// This needs to be called before the next message starts processing because we only keep track of one partially
    /// processed session.
    ///
    /// - Parameters:
    ///   - session: Session to persist properties for
    func updatePeerRatchetsNewSessionCommittedSendDateAndVersions(
        session: DHSession
    ) throws {
        // Update ratchets in store (don't use storeDHSession(), as otherwise we
        // might overwrite the "my" ratchets if an outgoing message is being processed
        // for the same session at the same time)
        try dhSessionStore.updateDHSessionRatchets(session: session, peer: true)
        
        try dhSessionStore.updateNewSessionCommitLastMessageSentDateAndVersions(session: session)
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
                // This is verbose because this function is called for all messages received from a contact with no FS
                DDLogVerbose(
                    "[ForwardSecurity] Don't warn for message (message-id=\(message.messageID.hexString)) received without FS as we do not have a session"
                )
                return
            }
            
            let minimumVersion = message.minimumRequiredForwardSecurityVersion()
            
            DDLogNotice(
                "[ForwardSecurity] \(minimumVersion != .unspecified && minimumVersion.rawValue <= bestSession.minimumIncomingAppliedVersion.rawValue ? "Maybe warn" : "Don't warn"). Checking message minimum version \(minimumVersion) against session \(bestSession.description) with minimumIncomingAppliedVersion \(bestSession.minimumIncomingAppliedVersion)"
            )
            
            if minimumVersion != .unspecified,
               minimumVersion.rawValue <= bestSession.minimumIncomingAppliedVersion.rawValue {
                Task {
                    let hasForwardSecuritySupport = await hasForwardSecuritySupport(sender)
                    
                    // TODO(ANDR-2452): Remove this feature mask update when enough clients have updated
                    // Check whether this contact still supports forward security when receiving a message without
                    // forward security.
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
                        DDLogNotice(
                            "[ForwardSecurity] Don't warn for message (message-id=\(message.messageID.hexString)) received without FS as contact has downgraded to an unsupported version"
                        )
                    }
                }
            }
        }
        catch {
            DDLogError("[ForwardSecurity] Could not get best session: \(error)")
        }
    }
    
    /// Process a `ForwardSecurityDataTerminate` message
    /// - Parameters:
    ///   - sender: Sender of message
    ///   - terminate: Terminate message
    private func processTerminate(
        sender: ForwardSecurityContact,
        terminate: ForwardSecurityDataTerminate
    ) async throws {
        DDLogNotice(
            "[ForwardSecurity] Terminating DH session ID \(terminate.sessionID) with \(sender.identity), cause: \(terminate.cause)"
        )
        
        // This order is verity particular, because when we update the feature mask in `ContactEntity` the sessions
        // might also be terminated...
        // (Improvements for this are tracked as part of SE-267)
        
        // 1. Delete the terminated session to prevent a termination & message for this session when the feature mask is
        // refreshed
        let sessionExists = try dhSessionStore.exactDHSession(
            myIdentity: identityStore.identity,
            peerIdentity: sender.identity,
            sessionID: terminate.sessionID
        ) != nil
        if !sessionExists {
            DDLogNotice(
                "[ForwardSecurity] We do not have a DH session ID \(terminate.sessionID) with \(sender.identity)"
            )
        }
        else {
            try dhSessionStore.deleteDHSession(
                myIdentity: identityStore.identity,
                peerIdentity: sender.identity,
                sessionID: terminate.sessionID
            )
        }

        // 2. Refresh feature mask to gain information if contact downgraded to a build without PFS
        //
        // We're waiting for the feature mask check to complete here. This is not great since we're stopping message
        // processing.
        // If the contact doesn't support PFS anymore, this might terminate all other sessions with this contact (a rare
        // case) and lead to a system message.
        let hasForwardSecuritySupport = await checkFSFeatureMask(for: sender)
        
        // 3. Post system message about termination, if the terminated session existed
        notifyListeners {
            $0.sessionTerminated(
                sessionID: terminate.sessionID,
                contact: sender,
                sessionUnknown: !sessionExists,
                hasForwardSecuritySupport: hasForwardSecuritySupport
            )
        }
    }
    
    private func sendMessageToContact(contact: ForwardSecurityContact, message: ForwardSecurityData) {
        let message = ForwardSecurityEnvelopeMessage(data: message)
        message.toIdentity = contact.identity
        messageSender.sendMessage(abstractMessage: message)
    }
    
    private func sendMessageToContact(identity: String, message: ForwardSecurityData) {
        let message = ForwardSecurityEnvelopeMessage(data: message)
        message.toIdentity = identity
        messageSender.sendMessage(abstractMessage: message)
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
    
    // MARK: Make helper
    
    private func newSession(with contact: ForwardSecurityContact) throws -> DHSession {
        let newSession = DHSession(
            peerIdentity: contact.identity,
            peerPublicKey: contact.publicKey,
            identityStore: identityStore
        )
        
        try dhSessionStore.storeDHSession(session: newSession)
        
        DDLogNotice("[ForwardSecurity] Starting new \(newSession)")
        notifyListeners { listener in
            listener.newSessionInitiated(session: newSession, contact: contact)
        }
        
        // Warn if the state is illegal
        if let state = try? newSession.state, state != .L20 {
            DDLogError(
                "[ForwardSecurity] Creating a new session in state that is not L20 is illegal (actual state: \(state))"
            )
            assertionFailure()
        }
        
        return newSession
    }
    
    private func canSend(_ message: AbstractMessage, in session: DHSession) -> Bool {
        guard let minimumRequiredForwardSecurityVersion = message.minimumRequiredForwardSecurityVersion else {
            DDLogNotice(
                "[ForwardSecurity] Can't send message with forward security because it is not yet supported: \(session)"
            )
            return false
        }
        
        guard minimumRequiredForwardSecurityVersion != .unspecified else {
            DDLogNotice(
                "[ForwardSecurity] Can't send message with forward security because it is not yet supported: \(session)"
            )
            return false
        }
        
        if case .UNRECOGNIZED = minimumRequiredForwardSecurityVersion {
            DDLogNotice(
                "[ForwardSecurity] Can't send message with forward security because it is not yet supported: \(session)"
            )
            return false
        }
        
        let isSendingSupported = (
            minimumRequiredForwardSecurityVersion.rawValue <= session.outgoingAppliedVersion.rawValue
        )
        
        DDLogNotice(
            "[ForwardSecurity] \(isSendingSupported ? "Send" : "Don't send") message with FS \(message.loggingDescription) (minRequired=\(minimumRequiredForwardSecurityVersion), applied=\(session.outgoingAppliedVersion), offered=\(session.outgoingOfferedVersion)) in \(session)"
        )
        
        return isSendingSupported
    }
    
    private func encapsulate(
        _ innerMessage: AbstractMessage,
        in session: DHSession
    ) throws -> ForwardSecurityEnvelopeMessage {
        DDLogVerbose(
            "[ForwardSecurity] Encapsulate message \(innerMessage.loggingDescription) in \(session.description)"
        )
        
        // Obtain encryption key from ratchet
        let (ratchetv, dhType, forwardSecurityMode): (
            KDFRatchet?,
            CspE2eFs_Encapsulated.DHType,
            ForwardSecurityMode
            // swiftformat:disable:next wrapMultilineConditionalAssignment
        ) = if session.myRatchet4DH == nil {
            // 2DH mode
            (
                session.myRatchet2DH,
                CspE2eFs_Encapsulated.DHType.twodh,
                .twoDH
            )
        }
        else {
            (
                session.myRatchet4DH,
                CspE2eFs_Encapsulated.DHType.fourdh,
                .fourDH
            )
        }
        
        guard let ratchet = ratchetv else {
            throw ForwardSecurityError.noDHModeNegotiated
        }
        
        let appliedVersion = session.outgoingAppliedVersion
        let currentKey = ratchet.currentEncryptionKey
        let counter = ratchet.counter
        ratchet.turn()
        
        // Update ratchets in store immediately to prevent key-reuse with the same nonce.
        // Otherwise if sending fails the message content might sightly change and we have a key-reuse with the same
        // nonce.
        // (don't use storeDHSession(), as otherwise we might overwrite the peer ratchets if an incoming message is
        // being processed for the same session at the same time)
        try dhSessionStore.updateDHSessionRatchets(session: session, peer: false)
        
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
        
        // Load group identity if it is a group message
        let groupIdentity: GroupIdentity?
        if let abstractGroupMessage = innerMessage as? AbstractGroupMessage {
            if let groupID = abstractGroupMessage.groupID,
               let groupCreatorIdentity = abstractGroupMessage.groupCreator {
                groupIdentity = GroupIdentity(id: groupID, creator: .init(groupCreatorIdentity))
            }
            else {
                DDLogError("[ForwardSecurity] Unable to create group identity from abstract group message")
                throw ForwardSecurityError.missingGroupIdentity
            }
        }
        else {
            groupIdentity = nil
        }
        
        DDLogDebug(
            "[ForwardSecurity] Create data message \(innerMessage.loggingDescription) offering \(session.outgoingOfferedVersion) in \(session)"
        )
        
        let dataMessage = ForwardSecurityDataMessage(
            sessionID: session.id,
            type: dhType,
            counter: counter,
            groupIdentity: groupIdentity,
            offeredVersion: session.outgoingOfferedVersion,
            appliedVersion: appliedVersion,
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
        
        // To get the correct returns on `AbstractMessage` flag calls we need to set `flags` on the outer message.
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
        
        return envelope
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
