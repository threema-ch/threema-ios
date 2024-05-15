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

// swiftformat:disable acronyms

import Foundation

/// Swiftification of constants from from `ProtocolDefines.h`
public enum ThreemaProtocol {
    public static let identityLength = Int(kIdentityLen)
    public static let messageIDLength = Int(kMessageIdLen)
    public static let nonceLength = Int(kNonceLen)
    public static let blobIDLength = Int(kBlobIdLen)
    public static let blobKeyLength = Int(kBlobKeyLen)
    public static let groupIDLength = Int(kGroupIdLen)
    public static let ballotIDLength = Int(kBallotIdLen)
    public static let deviceIDLength = Int(kDeviceIdLen)
    public static let publicKeyLength = Int(kNaClCryptoPubKeySize)
    public static let reflectIDLength = MediatorMessageProtocol.MEDIATOR_REFLECT_ID_LENGTH
    
    /// kNonce_1[]
    static let nonce01 = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    ])
    
    /// kNonce_2[]
    static let nonce02 = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
    ])
    
    /// Used for blobs in local note groups
    static let nonUploadedBlobID = Data(BytesUtility.padding([], pad: 0, length: blobIDLength))
}

@objc public enum ThreemaProtocolError: Int, Error, CustomStringConvertible {
    public typealias RawValue = Int

    case badMessage = 667
    case blockUnknownContact = 666
    case generalError = 100
    case messageAlreadyProcessed = 671
    case messageBlobDecryptionFailed = 673
    case messageNonceReuse = 674
    case messageProcessingFailed = 669
    case messageSenderMismatch = 679
    case messageToDeleteNotFound = 678
    case messageToEditNotFound = 677
    case notConnectedToMediator = 676
    case notLoggedIn = 675
    case safePasswordEmpty = 672
    case unknownMessageType = 668

    public var description: String {
        let rawError = "ThreemaProtocolError(rawValue: \(rawValue))"

        switch self {
        case .badMessage:
            return "\(rawError) 'Invalid message format or decryption failure'"
        case .blockUnknownContact:
            return "\(rawError) 'Unknown contact is blocked'"
        case .generalError:
            return "\(rawError) 'General error'"
        case .messageAlreadyProcessed:
            return "\(rawError) 'Message already processed'"
        case .messageBlobDecryptionFailed:
            return "\(rawError) 'Blob decryption failure'"
        case .messageNonceReuse:
            return "\(rawError) 'Reuse of message nonce'"
        case .messageProcessingFailed:
            return "\(rawError) 'Processing of message failed'"
        case .messageSenderMismatch:
            return "\(rawError) 'Message sender mismatch'"
        case .messageToDeleteNotFound:
            return "\(rawError) 'Message to delete not found'"
        case .messageToEditNotFound:
            return "\(rawError) 'Message to edit not found'"
        case .notConnectedToMediator:
            return "\(rawError) 'Not connected to mediator'"
        case .notLoggedIn:
            return "\(rawError) 'Not logged in'"
        case .safePasswordEmpty:
            return "\(rawError) 'Threema Safe password is missing'"
        case .unknownMessageType:
            return "\(rawError) 'Unknown message type'"
        }
    }
}

// MARK: - ForwardSecurityMode + CustomStringConvertible

extension ForwardSecurityMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .twoDH:
            return "2DH"
        case .fourDH:
            return "4DH"
        case .outgoingGroupNone:
            return "outgoing group: none"
        case .outgoingGroupPartial:
            return "outgoing group: partial"
        case .outgoingGroupFull:
            return "outgoing group: full"
        @unknown default:
            return "unknown"
        }
    }

    public var localizedLabel: String {
        switch self {
        case .none, .outgoingGroupNone:
            return "forward_security_none".localized
        case .twoDH:
            return "forward_security_2dh".localized
        case .fourDH:
            return "forward_security_4dh".localized
        case .outgoingGroupPartial:
            return "forward_security_outgoing_group_partial".localized
        case .outgoingGroupFull:
            return "forward_security_outgoing_group_full".localized
        @unknown default:
            return "forward_security_none".localized
        }
    }
}
