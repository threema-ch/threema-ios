//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class DeviceGroupDerivedKeyTests: XCTestCase {

    func testDerive() throws {
        
        let dgk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8, 0xBA,
        ]
        
        XCTAssertEqual(
            BytesUtility.toHexString(bytes: dgk),
            "1b35ed7e1ba9993171fe4a7eed30c2831905c3a583616d61e93782da900bf8ba"
        )
        
        let deviceGroupDerivedKey = try DeviceGroupDerivedKey(dgk: Data(dgk))

        XCTAssertEqual(
            deviceGroupDerivedKey.dgpk.hexString,
            "60c0ed9098902c0b6093be4a819bf344900bc7473504ccdb61004b1b58aa2233"
        )
    }
    
    func testDgkTooSmall() throws {
        let dgk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8,
        ]

        let result = try XCTExpectFailure {
            try DeviceGroupDerivedKey(dgk: Data(dgk))
        }

        XCTAssertNil(result)
    }

    func testDgkTooBig() throws {
        let dgk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8, 0xBA, 0xBA,
        ]

        let result = try XCTExpectFailure {
            try DeviceGroupDerivedKey(dgk: Data(dgk))
        }

        XCTAssertNil(result)
    }

    func testDeriveMany() throws {
        struct TestDerived {
            let dgpk: String
            let dgrk: String
            let dgdik: String
            let dgsddk: String
            let dgtsk: String
        }

        let testVectors: [String: TestDerived] =
            [
                "1b35ed7e1ba9993171fe4a7eed30c2831905c3a583616d61e93782da900bf8ba": TestDerived(
                    dgpk: "60c0ed9098902c0b6093be4a819bf344900bc7473504ccdb61004b1b58aa2233",
                    dgrk: "a4bf34ff67ed3b731a2aa6e023335f7eba6c914e877da3d15bff41d84f7f75f8",
                    dgdik: "5953fb9775d8c23fae573e245534dac2c7aa16b62ea73b954ea4177d192e8c50",
                    dgsddk: "7a91ad36bc9537ccfd6fd76b23d7f5319e506e6a5294c988c9a75c8e34a3c9dd",
                    dgtsk: "7c6b94affb171c564bfd375d50c4781d72ab2671ae4035ab4307dedce67ef30e"
                ),
                "7cf1c4847fb32d6c3702747018d0cccdc2f724c115bfca1036ae6208d2b7c68c": TestDerived(
                    dgpk: "2b59e83e5a93ce4a09eeb4db91ec30e63cc3f173385742dd4a27ef83e5bef4f3",
                    dgrk: "fa33785f528439c2bfd9b7220ff03ebca919c1c127aca91878f2038b65a79c73",
                    dgdik: "8a8199023dfeda5793e06552fb968282d7e7e29452c1229dcb212fb7d48f1e6a",
                    dgsddk: "bd96dd0f700c5d77da666990854eb4287d5f20a9be0deda6d88b875963c39b3f",
                    dgtsk: "351e81590fb0115f8d1ab604c7eaf6996f3e079ea0a591db62caea4dcd7c6bda"
                ),
                "0000000000000000000000000000000000000000000000000000000000000000": TestDerived(
                    dgpk: "4b464e5d33debe0d3f9be535b9a1449f79caac615c852da734b47ef3a23e14ca",
                    dgrk: "d597f6380d1ecf6f1a7fd265c49bc53cff04c0efc1236a542dae338bba4bc6e9",
                    dgdik: "8bb45615b2982e8d6aefcfbe46a44bcea0df048df7a05d9d50afd01911ed10d8",
                    dgsddk: "86fa7962c7d85e01876de9a90cad95cf83b4605d40b83b6580b80618f56fa4d4",
                    dgtsk: "7ab0a7c3239323e1b9f697eb59196d888747f027df356a305f58f55ebb8c23aa"
                ),
            ]

        for testVector in testVectors {
            let dgk = Data(BytesUtility.toBytes(hexString: testVector.key)!)
            let deviceGroupDerivedKey = try DeviceGroupDerivedKey(dgk: dgk)

            XCTAssertEqual(testVector.value.dgpk, deviceGroupDerivedKey.dgpk.hexString)
            XCTAssertEqual(testVector.value.dgrk, deviceGroupDerivedKey.dgrk.hexString)
            XCTAssertEqual(testVector.value.dgdik, deviceGroupDerivedKey.dgdik.hexString)
            XCTAssertEqual(testVector.value.dgsddk, deviceGroupDerivedKey.dgsddk.hexString)
            XCTAssertEqual(testVector.value.dgtsk, deviceGroupDerivedKey.dgtsk.hexString)
        }
    }
}
