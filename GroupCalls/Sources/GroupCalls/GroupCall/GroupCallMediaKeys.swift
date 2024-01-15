//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
final class MediaKeys {
    // MARK: - Internal Properties
    
    var protocolMediaKey: Groupcall_ParticipantToParticipant.MediaKey {
        var mediaKey = Groupcall_ParticipantToParticipant.MediaKey()
        mediaKey.epoch = UInt32(epoch)
        mediaKey.ratchetCounter = UInt32(ratchetCounter)
        mediaKey.pcmk = pcmk
        
        return mediaKey
    }
   
    // MARK: - Private Properties

    private var pcmk: Data
    private let dependencies: Dependencies
    
    var epoch = 0
    private var ratchetCounter = 0
    
    // MARK: - Lifecycle
    
    convenience init(dependencies: Dependencies) {
        let pcmk = dependencies.groupCallCrypto.randomBytes(of: ProtocolDefines.mediaKeyLength)
        
        self.init(pcmk: pcmk, dependencies: dependencies)
    }
    
    convenience init(pcmk: Data, dependencies: Dependencies) {
        self.init(pcmk: pcmk, epoch: 0, ratchetCounter: 0, dependencies: dependencies)
    }
    
    init(pcmk: Data, epoch: Int, ratchetCounter: Int, dependencies: Dependencies) {
        self.pcmk = pcmk
        self.epoch = epoch
        self.ratchetCounter = ratchetCounter
        self.dependencies = dependencies
    }
    
    // MARK: - Update Functions
    
    func ratchet() throws {
        /// **Protocol Step: Join/Leave of Other Participants (Join 2.)**
        /// Join 2. If the amount of ratchet rounds for `pcmk` is `255`, abort the call with an error condition and
        /// abort these steps.
        if ratchetCounter >= 255 {
            throw MediaKeyError.RatchetCounterTooLarge
        }
        
        /// **Protocol Step: Join/Leave of Other Participants (Join 3.)**
        /// Join 3. Advance the ratchet of `pcmk` once (i.e. replace the key by deriving PCMK') and apply for media
        /// encryption immediately. Note: Do **not** reset the MFSN!
        ratchetCounter += 1
        pcmk = try GroupCallKeys.deriveNextPCMK(from: pcmk)
    }
    
    func applyMediaKeys(to encryptor: ThreemaGroupCallFrameCryptoEncryptorProtocol) throws {
        guard epoch < UInt8.max else {
            DDLogError(
                "[GroupCall] Could not apply pcmk because epoch was too big. \(epoch) but maximum is \(UInt8.max)"
            )
            throw GroupCallError.keyRatchetError
        }
        
        guard ratchetCounter < UInt8.max else {
            DDLogError(
                "[GroupCall] Could not apply pcmk because ratchetCounter was too big. \(ratchetCounter) but maximum is \(UInt8.max)"
            )
            throw GroupCallError.keyRatchetError
        }
        
        let uint8Epoch = UInt8(epoch)
        let uint8Ratchet = UInt8(ratchetCounter)
        
        encryptor.setPcmk(pcmk, epoch: uint8Epoch, ratchetCounter: uint8Ratchet)
    }
    
    func applyMediaKeys(to decryptor: ThreemaGroupCallFrameCryptoDecryptorProtocol) throws {
        guard epoch < UInt8.max else {
            DDLogError(
                "[GroupCall] Could not apply pcmk because epoch was too big. \(epoch) but maximum is \(UInt8.max)"
            )
            throw GroupCallError.keyRatchetError
        }
        
        guard ratchetCounter < UInt8.max else {
            DDLogError(
                "[GroupCall] Could not apply pcmk because ratchetCounter was too big. \(ratchetCounter) but maximum is \(UInt8.max)"
            )
            throw GroupCallError.keyRatchetError
        }
        
        let uint8Epoch = UInt8(epoch)
        let uint8Ratchet = UInt8(ratchetCounter)
        
        decryptor.addPcmk(pcmk, epoch: uint8Epoch, ratchetCounter: uint8Ratchet)
    }
}

// MARK: - MediaKeys.MediaKeyError

extension MediaKeys {
    enum MediaKeyError: Error {
        case RatchetCounterTooLarge
        case General
    }
}
