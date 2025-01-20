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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

final class RendezvousProtocolTests: XCTestCase {

    // This tests the happy path
    func testResponderHandshakeAsNominator() async throws {
        let expectedAuthResponse = Data(repeating: 0x12, count: 16)
        let expectedPathHash = Data(repeating: 0x43, count: 10)
        
        let rendezvousInit = Rendezvous_RendezvousInit()
        let urlDeviceGroupJoinRequestOrOffer = Url_DeviceGroupJoinRequestOrOffer.with {
            $0.version = .v10
            $0.variant.requestToJoin = Common_Unit()
            $0.rendezvousInit = rendezvousInit
        }
        
        let encryptedRendezvousConnectionMock = EncryptedRendezvousConnectionMock {
            guard let lastDataSent = $0.dataSent.last else {
                throw EncryptedRendezvousConnectionError.unknownDataReceived
            }
            
            let helloMessage = try Rendezvous_Handshake.RrdToRid.Hello(serializedData: lastDataSent)
            
            return try Rendezvous_Handshake.RidToRrd.AuthHello.with {
                $0.response = helloMessage.challenge
                $0.challenge = expectedAuthResponse
            }.serializedData()
        }
        let rendezvousCryptoMock = RendezvousCryptoMock(switchDataToReturn: expectedPathHash)
        let encryptedRendezvousConnectionCreatorMock = EncryptedRendezvousConnectionCreatorMock(
            encryptedRendezvousConnectionMock: encryptedRendezvousConnectionMock,
            rendezvousCryptoMock: rendezvousCryptoMock
        )
        
        // Run
        
        let (actualConnection, pathHash) = try await RendezvousProtocol.connect(
            urlSafeBase64DeviceGroupJoinRequestOffer: urlDeviceGroupJoinRequestOrOffer.serializedData()
                .urlSafeBase64EncodedString(),
            isNominator: true,
            encryptedRendezvousConnectionCreator: encryptedRendezvousConnectionCreatorMock
        )
        
        // Validate
                
        // `Hello`, `Auth` & `Nominate` sent
        XCTAssertEqual(encryptedRendezvousConnectionMock.dataSent.count, 3)
        // `AuthHello` received
        XCTAssertEqual(encryptedRendezvousConnectionMock.receiveCallsCount, 1)
        
        let actualAuthData = encryptedRendezvousConnectionMock.dataSent[1]
        let actualAuthMessage = try Rendezvous_Handshake.RrdToRid.Auth(serializedData: actualAuthData)
        XCTAssertEqual(actualAuthMessage.response, expectedAuthResponse)
        
        // Switch should only be called once
        XCTAssertEqual(rendezvousCryptoMock.switchedToTransportKeysCalled, 1)
        
        let actualNominateData = encryptedRendezvousConnectionMock.dataSent[2]
        // This will throw if the 3rd message is not a nominate message
        _ = try Rendezvous_Nominate(serializedData: actualNominateData)
        
        XCTAssertTrue(actualConnection === encryptedRendezvousConnectionMock)
        XCTAssertEqual(pathHash, expectedPathHash)
    }
}
