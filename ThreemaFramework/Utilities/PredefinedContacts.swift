import Foundation
import ThreemaEssentials

/// Verify whether this contact is predefined by default.
public enum PredefinedContacts: String {
    case threema
    case threemaWork
    case support
    case myThreemaData
    case betaFeedback
    case threemaPush
    case threemaToken
    case threemaW0rk // From identity of the WorkSyncDelta message
    case unknown
    
    /// Initialize for predefined contacts
    /// - Parameter rawValue: Identity string
    public init(rawValue: String) {
        switch rawValue.uppercased() {
        case PredefinedContacts.threema.identity?.rawValue: self = .threema
        case PredefinedContacts.threemaWork.identity?.rawValue: self = .threemaWork
        case PredefinedContacts.support.identity?.rawValue: self = .support
        case PredefinedContacts.myThreemaData.identity?.rawValue: self = .myThreemaData
        case PredefinedContacts.betaFeedback.identity?.rawValue: self = .betaFeedback
        case PredefinedContacts.threemaPush.identity?.rawValue: self = .threemaPush
        case PredefinedContacts.threemaToken.identity?.rawValue: self = .threemaToken
        case PredefinedContacts.threemaW0rk.identity?.rawValue: self = .threemaW0rk
        default: self = .unknown
        }
    }
    
    /// Obtain the ThreemaIdentity of the current case.
    public var identity: ThreemaIdentity? {
        switch self {
        case .threema:
            ThreemaIdentity("*THREEMA")
        case .threemaWork:
            ThreemaIdentity("*3MAWORK")
        case .support:
            ThreemaIdentity("*SUPPORT")
        case .myThreemaData:
            ThreemaIdentity("*MY3DATA")
        case .betaFeedback:
            ThreemaIdentity("*BETAFBK")
        case .threemaPush:
            ThreemaIdentity("*3MAPUSH")
        case .threemaToken:
            ThreemaIdentity("*3MATOKN")
        case .threemaW0rk:
            ThreemaIdentity("*3MAW0RK")
        case .unknown:
            nil
        }
    }
    
    /// Special contacts, akin to Threema Push and Threema W0rk, require unique handling.
    /// Incoming messages from these contacts should not be stored in the database and
    /// necessitate special processing.
    var isSpecialContact: Bool {
        switch self {
        case .threemaPush, .threemaW0rk:
            true
        case .threema, .threemaWork, .support, .myThreemaData, .betaFeedback, .threemaToken, .unknown:
            false
        }
    }
    
    /// The public key for the current case
    var publicKey: Data? {
        switch self {
        case .threema:
            "3a38650c681435bd1fb8498e213a2919b09388f5803aa44640e0f706326a865c".hexadecimal
        case .threemaWork:
            "9aa0a72a8fb6f0cc53727fea6096f1b7b0ebefcc2650ad39a1e54837bba0bc4b".hexadecimal
        case .support:
            "0f944d18324b2132c61d8e40afce60a0ebd701bb11e89be94972d4229e94722a".hexadecimal
        case .myThreemaData:
            if TargetManager.isSandbox {
                "83adfee6558b68ae3cd6bbe2a33f4e4409d5624a7cea23a18975aea6272a0070".hexadecimal
            }
            else {
                "3b01854f24736e2d0d2dc387eaf2c0273c5049052147132369bf3960d0a0bf02".hexadecimal
            }
        case .betaFeedback:
            if TargetManager.isSandbox {
                nil
            }
            else {
                "5684d6dcd32a16488df8371095fc9a1fc25baeb6b97366d99fdf2aba00e2bc5c".hexadecimal
            }
        case .threemaPush:
            "fd711e1a0db0e2f03fcaab6c43da2575b9513664a62a12bd0728d87f7125cc24".hexadecimal
        case .threemaToken:
            if TargetManager.isSandbox {
                nil
            }
            else {
                "04884d12d668f855d00d71fb1d9d413c95f271312f7e077846af671875c4101b".hexadecimal
            }
        case .threemaW0rk:
            if TargetManager.isSandbox {
                "c79d9e0f70342e653b0c6df027af8c8681db40e11bf556dd33ec78ee6f810c6d".hexadecimal
            }
            else {
                "c0e8ad0f50c5c7315c402d3dc26db169408c117613e9b852d3d6c0e87fca536b".hexadecimal
            }
        case .unknown:
            nil
        }
    }
    
    /// Verify the validity of the provided public key with the corresponding identity.
    /// - Parameter publicKey: The public key of the contact.
    /// - Returns: Bool
    func isSamePublicKey(_ publicKey: Data) -> Bool {
        guard self != .unknown else {
            return false
        }
        
        return publicKey == self.publicKey
    }
}

/// Verify whether this contact is predefined by default
@available(swift, obsoleted: 1.0, renamed: "PredefinedContacts", message: "Only use from Objective-C")
final class PredefinedContactsObjC: NSObject {
    @objc static func publicKey(for identity: String) -> Data? {
        PredefinedContacts(rawValue: identity).publicKey
    }

    @objc static func isSpecialContact(identity: String) -> Bool {
        PredefinedContacts(rawValue: identity).isSpecialContact
    }

    /// Verify whether this contact is predefined by default.
    /// - Parameters:
    ///   - identity: Identity string
    ///   - publicKey: Public Key
    /// - Returns: Boolean indicating whether the contact is predefined or not.
    @objc static func isPredefinedContact(identity: String, publicKey: Data) -> Bool {
        PredefinedContacts(rawValue: identity).isSamePublicKey(publicKey)
    }
    
    /// Verify whether the provided identity is indeed '*3MAPUSH*'.
    /// - Parameter identity: Identity string
    /// - Returns: A boolean flag indicating whether the identity is *3MAPUSH*.
    @objc static func is3MAPush(identity: String) -> Bool {
        PredefinedContacts(rawValue: identity) == .threemaPush
    }

    /// Verify whether the provided identity is indeed '*3MAW0RK*'.
    /// - Parameter identity: Identity string
    /// - Returns: A boolean flag indicating whether the identity is *3MAW0RK*.
    @objc static func is3MAW0rk(identity: String) -> Bool {
        PredefinedContacts(rawValue: identity) == .threemaW0rk
    }
}
