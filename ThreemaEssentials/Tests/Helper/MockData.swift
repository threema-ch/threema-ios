//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import ThreemaEssentials

public class MockData {

    public static func generateBallotID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.ballotIDLength)!
    }

    public static func generateBlobID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
    }

    public static func generateBlobEncryptionKey() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobKeyLength)!
    }

    public static func generateMessageID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
    }

    public static func generateMessageNonce() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.nonceLength)!
    }

    public static func generateGroupID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
    }

    public static func generatePublicKey() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.publicKeyLength)!
    }

    public static func generateReflectID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.reflectIDLength)!
    }
    
    public static func generateGCK() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.gckLength)!
    }

    public static func generateDeviceGroupKey() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceGroupKeyLength)!
    }

    public static func generateDeviceID() -> Data {
        BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!
    }
}
