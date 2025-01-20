//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

/// Check if this contact is trusted by default
enum TrustedContacts: String {
    case threema
    case threemaWork
    case support
    case myThreemaData
    case betaFeedback
    case threemaPush
    case threemaToken
    case unknown
    
    private static let threemaGatewayID = "*THREEMA"
    private static let threemaWorkGatewayID = "*3MAWORK"
    private static let supportGatewayID = "*SUPPORT"
    private static let myThreemaDataGatewayID = "*MY3DATA"
    private static let betaFeedbackGatewayID = "*BETAFBK"
    private static let threemaPushGatewayID = "*3MAPUSH"
    private static let threemaTokenGatewayID = "*3MATOKN"
    
    public var identity: String? {
        switch self {
        case .threema:
            TrustedContacts.threemaGatewayID
        case .threemaWork:
            TrustedContacts.threemaWorkGatewayID
        case .support:
            TrustedContacts.supportGatewayID
        case .myThreemaData:
            TrustedContacts.myThreemaDataGatewayID
        case .betaFeedback:
            TrustedContacts.betaFeedbackGatewayID
        case .threemaPush:
            TrustedContacts.threemaPushGatewayID
        case .threemaToken:
            TrustedContacts.threemaTokenGatewayID
        case .unknown:
            nil
        }
    }

    var ignoreBlockUnknown: Bool {
        switch self {
        case .threema, .threemaWork, .support, .myThreemaData, .betaFeedback, .threemaPush, .threemaToken:
            true
        case .unknown:
            false
        }
    }
    
    init(rawValue: String) {
        switch rawValue.uppercased() {
        case TrustedContacts.threemaGatewayID: self = .threema
        case TrustedContacts.threemaWorkGatewayID: self = .threemaWork
        case TrustedContacts.supportGatewayID: self = .support
        case TrustedContacts.myThreemaDataGatewayID: self = .myThreemaData
        case TrustedContacts.betaFeedbackGatewayID: self = .betaFeedback
        case TrustedContacts.threemaPushGatewayID: self = .threemaPush
        case TrustedContacts.threemaTokenGatewayID: self = .threemaToken
        default: self = .unknown
        }
    }
    
    private var publicKey: Data? {
        switch self {
        case .threema:
            "3a38650c681435bd1fb8498e213a2919b09388f5803aa44640e0f706326a865c".hexadecimal
        case .threemaWork:
            "9aa0a72a8fb6f0cc53727fea6096f1b7b0ebefcc2650ad39a1e54837bba0bc4b".hexadecimal
        case .support:
            "0f944d18324b2132c61d8e40afce60a0ebd701bb11e89be94972d4229e94722a".hexadecimal
        case .myThreemaData:
            "3b01854f24736e2d0d2dc387eaf2c0273c5049052147132369bf3960d0a0bf02".hexadecimal
        case .betaFeedback:
            "5684d6dcd32a16488df8371095fc9a1fc25baeb6b97366d99fdf2aba00e2bc5c".hexadecimal
        case .threemaPush:
            "fd711e1a0db0e2f03fcaab6c43da2575b9513664a62a12bd0728d87f7125cc24".hexadecimal
        case .threemaToken:
            "04884d12d668f855d00d71fb1d9d413c95f271312f7e077846af671875c4101b".hexadecimal
        case .unknown:
            nil
        }
    }
    
    /// Check is the given public key valid to the id
    /// - Parameter publicKey: Public key of the contact
    /// - Returns: Bool
    func isSamePublicKey(_ publicKey: Data) -> Bool {
        guard self != .unknown else {
            return false
        }
        
        return publicKey == self.publicKey
    }
}

@available(*, deprecated, message: "Only use this from obj-c.")
/// Check if this contact is trusted by default
@objc class TrustedContactsObjc: NSObject {
    @objc static func isTrustedContact(identity: String, publicKey: Data) -> Bool {
        TrustedContacts(rawValue: identity).isSamePublicKey(publicKey)
    }
    
    @objc static func ignoreBlockUnknown(identity: String) -> Bool {
        TrustedContacts(rawValue: identity).ignoreBlockUnknown
    }
}
