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

public class DHSession: CustomStringConvertible, Equatable {
    static let keSalt2DHPrefix = "ke-2dh-"
    static let keSalt4DHPrefix = "ke-4dh-"
    static let kdfPersonal = "3ma-e2e"
    
    let id: DHSessionID
    let myIdentity: String
    let peerIdentity: String
    private(set) var myEphemeralPrivateKey: Data?
    private(set) var myEphemeralPublicKey: Data!
    
    var myRatchet2DH: KDFRatchet?
    var myRatchet4DH: KDFRatchet?
    var peerRatchet2DH: KDFRatchet?
    var peerRatchet4DH: KDFRatchet?
    
    /// Create a new DHSession as an initiator, using a new random session ID and
    /// a new random private key.
    init(peerIdentity: String, peerPublicKey: Data, identityStore: MyIdentityStoreProtocol) {
        self.id = DHSessionID()
        self.myIdentity = identityStore.identity
        self.peerIdentity = peerIdentity
        
        var newPublicKey: NSData?
        var newPrivateKey: NSData?
        NaClCrypto.shared().generateKeyPairPublicKey(&newPublicKey, secretKey: &newPrivateKey)
        
        self.myEphemeralPublicKey = newPublicKey! as Data
        self.myEphemeralPrivateKey = newPrivateKey! as Data
        
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKey)!
        
        initKDF2DH(dhStaticStatic: dhStaticStatic, dhStaticEphemeral: dhStaticEphemeral, peer: false)
    }
    
    /// Create a new DHSession as a responder.
    init(
        id: DHSessionID,
        peerEphemeralPublicKey: Data,
        peerIdentity: String,
        peerPublicKey: Data,
        identityStore: MyIdentityStoreProtocol
    ) throws {
        if peerEphemeralPublicKey.count != kNaClCryptoPubKeySize {
            throw DHSessionError.invalidPublicKeyLength
        }
        
        self.id = id
        self.myIdentity = identityStore.identity
        self.peerIdentity = peerIdentity
        
        self.myEphemeralPublicKey = completeKeyExchange(
            peerEphemeralPublicKey: peerEphemeralPublicKey,
            peerPublicKey: peerPublicKey,
            identityStore: identityStore
        )
    }
    
    /// Create a DHSession with existing data, e.g. read from a persistent store.
    init(
        id: DHSessionID,
        myIdentity: String,
        peerIdentity: String,
        myEphemeralPrivateKey: Data?,
        myEphemeralPublicKey: Data,
        myRatchet2DH: KDFRatchet?,
        myRatchet4DH: KDFRatchet?,
        peerRatchet2DH: KDFRatchet?,
        peerRatchet4DH: KDFRatchet?
    ) {
        
        self.id = id
        self.myIdentity = myIdentity
        self.peerIdentity = peerIdentity
        self.myEphemeralPrivateKey = myEphemeralPrivateKey
        self.myEphemeralPublicKey = myEphemeralPublicKey
        self.myRatchet2DH = myRatchet2DH
        self.myRatchet4DH = myRatchet4DH
        self.peerRatchet2DH = peerRatchet2DH
        self.peerRatchet4DH = peerRatchet4DH
    }
    
    /// Process a DH accept received from the peer.
    public func processAccept(
        peerEphemeralPublicKey: Data,
        peerPublicKey: Data,
        identityStore: MyIdentityStoreProtocol
    ) throws {
        guard let myEphemeralPrivateKey else {
            throw DHSessionError.missingEphemeralPrivateKey
        }
        
        // Derive 4DH root key
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKey)!
        let dhEphemeralStatic = identityStore.sharedSecret(withPublicKey: peerEphemeralPublicKey)!
        let dhEphemeralEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerEphemeralPublicKey, secretKey: myEphemeralPrivateKey)!
        initKDF4DH(
            dhStaticStatic: dhStaticStatic,
            dhStaticEphemeral: dhStaticEphemeral,
            dhEphemeralStatic: dhEphemeralStatic,
            dhEphemeralEphemeral: dhEphemeralEphemeral
        )
        
        // myEphemeralPrivateKey is not needed anymore at this point
        self.myEphemeralPrivateKey = nil
        
        // My 2DH ratchet is not needed anymore at this point, but the peer 2DH ratchet is still
        // needed until we receive the first 4DH message, as there may be some 2DH messages still
        // in flight.
        myRatchet2DH = nil
    }
    
    /// Discard the 2DH peer ratchet associated with this session (because a 4DH message has been received).
    public func discardPeerRatchet2DH() {
        peerRatchet2DH = nil
    }
    
    private func initKDF2DH(dhStaticStatic: Data, dhStaticEphemeral: Data, peer: Bool) {
        // We can feed the combined 64 bytes directly into BLAKE2b
        let kdf = ThreemaKDF(personal: DHSession.kdfPersonal)
        if peer {
            let peerK0 = kdf.deriveKey(
                salt: DHSession.keSalt2DHPrefix + peerIdentity,
                key: dhStaticStatic + dhStaticEphemeral
            )!
            peerRatchet2DH = KDFRatchet(counter: 1, initialChainKey: peerK0)
        }
        else {
            let myK0 = kdf.deriveKey(
                salt: DHSession.keSalt2DHPrefix + myIdentity,
                key: dhStaticStatic + dhStaticEphemeral
            )!
            myRatchet2DH = KDFRatchet(counter: 1, initialChainKey: myK0)
        }
    }
    
    private func initKDF4DH(
        dhStaticStatic: Data,
        dhStaticEphemeral: Data,
        dhEphemeralStatic: Data,
        dhEphemeralEphemeral: Data
    ) {
        // The combined 128 bytes need to be hashed with plain BLAKE2b (512 bit output) first
        let intermediateHash = ThreemaKDF
            .hash(input: dhStaticStatic + dhStaticEphemeral + dhEphemeralStatic + dhEphemeralEphemeral, outputLen: 64)!
        
        let kdf = ThreemaKDF(personal: DHSession.kdfPersonal)
        let myK = kdf.deriveKey(salt: DHSession.keSalt4DHPrefix + myIdentity, key: intermediateHash)!
        let peerK = kdf.deriveKey(salt: DHSession.keSalt4DHPrefix + peerIdentity, key: intermediateHash)!
        
        myRatchet4DH = KDFRatchet(counter: 1, initialChainKey: myK)
        peerRatchet4DH = KDFRatchet(counter: 1, initialChainKey: peerK)
    }
    
    private func completeKeyExchange(
        peerEphemeralPublicKey: Data,
        peerPublicKey: Data,
        identityStore: MyIdentityStoreProtocol
    ) -> Data {
        var myEphemeralPublicKeyLocal: NSData?
        var myEphemeralPrivateKeyLocal: NSData?
        NaClCrypto.shared().generateKeyPairPublicKey(&myEphemeralPublicKeyLocal, secretKey: &myEphemeralPrivateKeyLocal)
        
        // Derive 2DH root key
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = identityStore.sharedSecret(withPublicKey: peerEphemeralPublicKey)!
        initKDF2DH(dhStaticStatic: dhStaticStatic, dhStaticEphemeral: dhStaticEphemeral, peer: true)
        
        // Derive 4DH root key
        let dhEphemeralStatic = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKeyLocal! as Data)!
        let dhEphemeralEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerEphemeralPublicKey, secretKey: myEphemeralPrivateKeyLocal! as Data)!
        initKDF4DH(
            dhStaticStatic: dhStaticStatic,
            dhStaticEphemeral: dhStaticEphemeral,
            dhEphemeralStatic: dhEphemeralStatic,
            dhEphemeralEphemeral: dhEphemeralEphemeral
        )
        
        return myEphemeralPublicKeyLocal! as Data
    }
    
    public static func == (lhs: DHSession, rhs: DHSession) -> Bool {
        lhs.id == rhs.id &&
            lhs.myIdentity == rhs.myIdentity &&
            lhs.peerIdentity == rhs.peerIdentity &&
            lhs.myEphemeralPublicKey == rhs.myEphemeralPublicKey &&
            lhs.myRatchet2DH == rhs.myRatchet2DH &&
            lhs.myRatchet4DH == rhs.myRatchet4DH &&
            lhs.peerRatchet2DH == rhs.peerRatchet2DH &&
            lhs.peerRatchet4DH == rhs.peerRatchet4DH
    }
    
    public var description: String {
        "DH session ID \(id) \(myIdentity) <> \(peerIdentity) (\(myRatchet4DH != nil ? "4DH" : "2DH"))"
    }
}

enum DHSessionError: Error {
    case missingEphemeralPrivateKey
    case invalidPublicKeyLength
}
