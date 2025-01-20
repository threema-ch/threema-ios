//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
@testable import ThreemaFramework

class MockData {

    static func generateBallotID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.ballotIDLength)!
    }

    static func generateBlobID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
    }

    static func generateBlobEncryptionKey() -> Data {
        BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
    }

    static func generateMessageID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
    }

    static func generateMessageNonce() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.nonceLength)!
    }

    static func generateGroupID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
    }

    static func generatePublicKey() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!
    }

    static func generateReflectID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.reflectIDLength)!
    }
    
    static func generateGCK() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.gckLength)!
    }

    // MARK: Static data

    static var deviceGroupKeys: DeviceGroupKeys {
        DeviceGroupKeys(
            dgpk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgrk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgdik: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgsddk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgtsk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            deviceGroupIDFirstByteHex: "a1"
        )
    }

    static var deviceID: Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!
    }
}
