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

// swiftformat:disable acronyms

import Foundation

/// Swiftification of constants from from `ProtocolDefines.h`
public enum ThreemaProtocol {
    public static let identityLength = Int(8) // -> kIdentityLen
    public static let messageIDLength = Int(8) // -> kMessageIdLen
    public static let nonceLength = Int(24) // -> kNonceLen
    public static let blobIDLength = Int(16) // -> kBlobIdLen
    public static let blobKeyLength = Int(32) // -> kBlobKeyLen
    public static let groupIDLength = Int(8) // -> kGroupIdLen
    public static let ballotIDLength = Int(8) // -> kBallotIdLen
    public static let deviceIDLength = Int(8) // -> kDeviceIdLen
    public static let gckLength = Int(32) // -> kGCKLen
    public static let publicKeyLength = Int(32) // -> kNaClCryptoPubKeySize
    public static let reflectIDLength = 4 // -> MediatorMessageProtocol.MEDIATOR_REFLECT_ID_LENGTH
    public static let deviceGroupKeyLength = 32 // -> kDeviceGroupKeyLen

    /// kNonce_1[]
    public static let nonce01 = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    ])

    /// kNonce_2[]
    public static let nonce02 = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
    ])

    /// Used for blobs in local note groups
    public static let nonUploadedBlobID = Data(BytesUtility.padding([], pad: 0, length: blobIDLength))
}
