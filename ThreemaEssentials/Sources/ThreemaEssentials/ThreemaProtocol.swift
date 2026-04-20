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
