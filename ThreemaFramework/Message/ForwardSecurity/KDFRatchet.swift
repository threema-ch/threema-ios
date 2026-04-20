import Foundation

public final class KDFRatchet: Equatable {
    /// Upper limit on how many times we are willing to turn the ratchet to catch up with a peer
    static let maxCounterIncrement = 25000
    
    static let kdfSaltCk = "kdf-ck"
    static let kdfSaltAek = "kdf-aek"
    
    private(set) var currentChainKey: Data
    private(set) var counter: UInt64
    
    init(counter: UInt64, initialChainKey: Data) {
        self.currentChainKey = initialChainKey
        self.counter = counter
    }
    
    /// Turn the ratchet once.
    public func turn() {
        currentChainKey = ThreemaKDF(personal: DHSession.kdfPersonal)
            .deriveKey(salt: KDFRatchet.kdfSaltCk, key: currentChainKey)!
        counter += 1
    }
    
    ///   Turn the ratchet until the desired counter value has been reached.
    ///   - Returns: the number of turns that were required
    public func turnUntil(targetCounterValue: UInt64) throws -> UInt64 {
        if counter == targetCounterValue {
            return 0
        }
        else if counter > targetCounterValue {
            throw RatchetRotationError.cannotGoBackwards
        }
        else if (targetCounterValue - counter) > KDFRatchet.maxCounterIncrement {
            throw RatchetRotationError.tooFarAhead
        }
        
        var numTurns: UInt64 = 0
        while counter < targetCounterValue {
            turn()
            numTurns += 1
        }
        return numTurns
    }
    
    public var currentEncryptionKey: Data {
        // The encryption key is derived from the chain key, but separate, so that
        // a leaked encryption key cannot be used to calculate any chain keys
        ThreemaKDF(personal: DHSession.kdfPersonal).deriveKey(salt: KDFRatchet.kdfSaltAek, key: currentChainKey)!
    }
    
    public static func == (lhs: KDFRatchet, rhs: KDFRatchet) -> Bool {
        lhs.currentChainKey == rhs.currentChainKey && lhs.counter == rhs.counter
    }
}

enum RatchetRotationError: Error {
    case cannotGoBackwards
    case tooFarAhead
}
