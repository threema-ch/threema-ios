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
    case pendingGroupMessage = 670
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
        case .pendingGroupMessage:
            return "\(rawError) 'Group not found to process message'"
        case .safePasswordEmpty:
            return "\(rawError) 'Threema Safe password is missing'"
        case .unknownMessageType:
            return "\(rawError) 'Unknown message type'"
        }
    }
}

extension ForwardSecurityMode {
    public var localizedLabel: String {
        switch self {
        case .none:
            return BundleUtil.localizedString(forKey: "forward_security_none")
        case .twoDH:
            return BundleUtil.localizedString(forKey: "forward_security_2dh")
        case .fourDH:
            return BundleUtil.localizedString(forKey: "forward_security_4dh")
        @unknown default:
            return BundleUtil.localizedString(forKey: "forward_security_none")
        }
    }
}
