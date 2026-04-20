import Foundation

public enum Rendezvous {
    public enum Role {
        case initiator
        case responder
    }
    
    static let challengeLength = 16
    static let ephemeralPublicKeyLength = 32
}
