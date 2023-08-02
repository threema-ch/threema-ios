//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import WebRTC

@GlobalGroupCallActor
final class LocalParticipant: NormalParticipant, Sendable {
    private let localContext: LocalContext
    
    private let dependencies: Dependencies
    
    private let localIdentity: ThreemaID
    
    private var mediaKeys: MediaKeys
    private var pendingMediaKeys: MediaKeys?
    private var pendingMediaKeysIsStale = false
    
    private let participantType: String
    private let keyPair: KeyPair
    /// Participant Call Cookie
    private let pcck: Data
    
    init(
        id: ParticipantID,
        contactModel: ContactModel,
        localContext: LocalContext,
        threemaID: ThreemaID,
        dependencies: Dependencies,
        localIdentity: ThreemaID
    ) {
        self.localContext = localContext
        self.participantType = "LocalParticipant"
        self.dependencies = dependencies
        
        let keys = self.dependencies.groupCallCrypto.generateKeyPair()
        self.keyPair = KeyPair(publicKey: keys.1, privateKey: keys.0)
        
        self.pcck = self.dependencies.groupCallCrypto.randomBytes(of: 16)
        self.localIdentity = localIdentity
        
        self.mediaKeys = MediaKeys(dependencies: dependencies)
        
        super.init(id: id, contactModel: contactModel, threemaID: threemaID)
    }
    
    var protocolMediaKeys: Groupcall_ParticipantToParticipant.MediaKey {
        mediaKeys.protocolMediaKey
    }
    
    var pendingProtocolMediaKeys: Groupcall_ParticipantToParticipant.MediaKey? {
        pendingMediaKeys?.protocolMediaKey
    }
    
    override var mirrorRenderer: Bool {
        // TODO: Implement
//        return localContext.cameraVideoContext.currentCamera?.facing == Camera.Facing.FRON
        false
    }
    
    override var microphoneActive: Bool {
        get {
            super.microphoneActive
        }
        set {
            DDLogNotice("Set microphone active=\(newValue)")
            super.microphoneActive = newValue
//            localContext.microphoneAudioContext.active = newValue
        }
    }
    
    override var cameraActive: Bool {
        get {
            super.cameraActive
        }
        set {
            DDLogNotice("Set camera active=\(newValue)")
            super.cameraActive = newValue
            DispatchQueue.main.async {
//                if newValue {
//                    self.localContext.cameraVideoContext.startCapturing()
//                } else {
//                    self.localContext.cameraVideoContext.stopCapturing()
//                }
            }
        }
    }
    
//    override func subscribeCamera(renderer: SurfaceViewRenderer, width: Int, height: Int, fps: Int) -> DetachSinkFn {
//        logger.trace("Subscribe local camera")
//        return localContext.cameraVideoContext.renderTo(renderer)
//    }
    
    override func unsubscribeCamera() {
        // no-op: Detach is performed in DetachSinkFn returned from subscribeCamera
    }
    
    func flipCamera() {
//        do {
//            try await localContext.cameraVideoContext.flipCamera()
//        } catch {
//            logger.warn("Could not toggle front/back camera", error)
//        }
    }
    
    func applyMediaKeys(to encryptor: ThreemaGroupCallFrameCryptoEncryptorProtocol) throws {
        try mediaKeys.applyMediaKeys(to: encryptor)
    }
}

// MARK: - Key Handling

extension LocalParticipant {
    func createNewMediaKeys() {
        mediaKeys = MediaKeys(dependencies: dependencies)
    }
    
    /// Runs the leave protocol steps 1 to 4
    func replaceAndApplyNewMediaKeys() throws {
        /// **Protocol Step: Join/Leave of Other Participants** 1. Let pending-pcmk be the currently pending PCMK the
        /// associated context.
        guard pendingMediaKeys == nil else {
            /// **Protocol Step: Join/Leave of Other Participants** 2. If pending-pcmk exists, additionally mark
            /// pending-pcmk as stale and abort these steps.
            pendingMediaKeysIsStale = true
            return
        }
        /// **Protocol Step: Join/Leave of Other Participants** 3. Let current-pcmk be the currently applied PCMK with
        /// the associated context.
        
        /// **Protocol Step: Join/Leave of Other Participants** 4. Set pending-pcmk in the following way:
        /// **Protocol Step: Join/Leave of Other Participants** 4.1. Generate a new cryptographically secure random PCMK
        /// and assign it to pending-pcmk.
        pendingMediaKeys = MediaKeys(dependencies: dependencies)
        pendingMediaKeysIsStale = false
        
        /// **Protocol Step: Join/Leave of Other Participants** 4.2. Set pending-pcmk.epoch to current-pcmk.epoch + 1,
        /// wrap back to 0 if it would be 256.
        if mediaKeys.epoch < 255 {
            pendingMediaKeys!.epoch = mediaKeys.epoch + 1
        }
        else {
            pendingMediaKeys!.epoch = 0
        }
       
        /// **Protocol Step: Join/Leave of Other Participants** 4.3. Set pending-pcmk.ratchet_counter to 0.
        // This is done on init of MediaKeys
        
        /// **Protocol Step: Join/Leave of Other Participants** 4.4. Do not reset the MFSN! Continue the existing MFSN
        /// counter of the previous PCMK.
        // Does not apply here, is done somewhere in the imported and patched WebRTC
    }
    
    func switchCurrentForPendingKeys() throws -> Bool {
        guard let pendingMediaKeys else {
            let msg = "[GroupCall] [Rekey] Expected to have pending keys but there were none"
            assertionFailure(msg)
            DDLogError(msg)
            throw FatalGroupCallError.LocalProtocolViolation
        }
        
        mediaKeys = pendingMediaKeys
        self.pendingMediaKeys = nil
        
        return pendingMediaKeysIsStale
    }
    
    func ratchetMediaKeys() throws {
        try mediaKeys.ratchet()
    }
}
