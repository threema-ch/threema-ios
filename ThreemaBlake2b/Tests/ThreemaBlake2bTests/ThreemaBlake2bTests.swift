//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
@testable import ThreemaBlake2b

final class ThreemaBlake2bTests: XCTestCase {
    
    // MARK: - Key derivation
    
    // First three test vectors from `multidevice-kdf/test-vectors-blake2b.csv`
    func testMultiDeviceTestVectors() throws {
        try keyDerivationTest(
            keyHex: "101692161c717bc3fe893b3dbcfe7424c725fd06624940a1046895fb83960240",
            saltHex: "492e",
            personalHex: "a390519d083d07c5",
            expectedHex: "ae810e70c16cc45692c1d4fedf323ca2ca0218d90dc0f969ab1a7aeb6d3039a8"
        )
        
        try keyDerivationTest(
            keyHex: "f8e2fcb4369c164e1cdfff82cb7a2c970f1b9a1553c143bf6aef588c1343c2da",
            saltHex: "aaf4ad00000000000000000000000000",
            personalHex: "9f4c909b3b27f8e50000000000000000",
            expectedHex: "5f316d0be440fc40b60bd1c90aab60f1de6f9e2de57d9d0f24b3a3fa02eda76a"
        )
        
        try keyDerivationTest(
            keyHex: "88f7c68a72c76747494fec2d9783e2948906d86b2458818b7e9ee7fce856cb72",
            saltHex: "00",
            personalHex: "ef2a504bdb21799200000000000000", // A padding byte is missing here
            expectedHex: "b4da86a0622262e4f8f8bce44aa6a3ee994b61997c1895af2803a98901914cc0"
        )
    }
    
    private func keyDerivationTest(
        keyHex: String,
        saltHex: String,
        personalHex: String,
        expectedHex: String
    ) throws {
        let keyData = try keyHex.hexData()
        let saltData = try saltHex.hexData()
        let personalData = try personalHex.hexData()
        
        let actualData = try ThreemaBlake2b.deriveKey(
            from: keyData,
            with: saltData,
            personal: personalData,
            derivedKeyLength: .b32
        )
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
    
    // Last test vector from `multidevice-kdf/test-vectors-blake2b.csv`
    func testInstanceKeyDerivation() throws {
        let expectedHex = "40e1b8e73cd8ab72c0d4560975bbcbb534a964f23ddc6a8d4f4c50d93f6d9b3f"
        
        let keyData = try "d6531aeba59f24ac38df2626bcc5c7cb06e453a773a604675ef957988e0bcbb6".hexData()
        let saltData = try "c6f95b".hexData()
        let personalData = try "953d8b141c51d0d8".hexData()
        
        let threemaBlake2b = try ThreemaBlake2b(personal: personalData)
        let actualKeyData = try threemaBlake2b.deriveKey(
            from: keyData,
            with: saltData,
            derivedKeyLength: .b32
        )
        
        XCTAssertEqual(actualKeyData.hexString, expectedHex)
    }
    
    // MARK: - Hashing
    
    // blake2b test vectors 1 to 10 from `blake2-kat.json`
    func testSingleInputHash() throws {
        try singleInputHashTest(
            inputHex: "",
            expectedHex: "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce"
        )
        
        try singleInputHashTest(
            inputHex: "00",
            expectedHex: "2fa3f686df876995167e7c2e5d74c4c7b6e48f8068fe0e44208344d480f7904c36963e44115fe3eb2a3ac8694c28bcb4f5a0f3276f2e79487d8219057a506e4b"
        )
        
        try singleInputHashTest(
            inputHex: "0001",
            expectedHex: "1c08798dc641aba9dee435e22519a4729a09b2bfe0ff00ef2dcd8ed6f8a07d15eaf4aee52bbf18ab5608a6190f70b90486c8a7d4873710b1115d3debbb4327b5"
        )
        
        try singleInputHashTest(
            inputHex: "000102",
            expectedHex: "40a374727302d9a4769c17b5f409ff32f58aa24ff122d7603e4fda1509e919d4107a52c57570a6d94e50967aea573b11f86f473f537565c66f7039830a85d186"
        )
        
        try singleInputHashTest(
            inputHex: "00010203",
            expectedHex: "77ddf4b14425eb3d053c1e84e3469d92c4cd910ed20f92035e0c99d8a7a86cecaf69f9663c20a7aa230bc82f60d22fb4a00b09d3eb8fc65ef547fe63c8d3ddce"
        )
        
        try singleInputHashTest(
            inputHex: "0001020304",
            expectedHex: "cbaa0ba7d482b1f301109ae41051991a3289bc1198005af226c5e4f103b66579f461361044c8ba3439ff12c515fb29c52161b7eb9c2837b76a5dc33f7cb2e2e8"
        )
        
        try singleInputHashTest(
            inputHex: "000102030405",
            expectedHex: "f95d45cf69af5c2023bdb505821e62e85d7caedf7beda12c0248775b0c88205eeb35af3a90816f6608ce7dd44ec28db1140614e1ddebf3aa9cd1843e0fad2c36"
        )
        
        try singleInputHashTest(
            inputHex: "00010203040506",
            expectedHex: "8f945ba700f2530e5c2a7df7d5dce0f83f9efc78c073fe71ae1f88204a4fd1cf70a073f5d1f942ed623aa16e90a871246c90c45b621b3401a5ddbd9df6264165"
        )
        
        try singleInputHashTest(
            inputHex: "0001020304050607",
            expectedHex: "e998e0dc03ec30eb99bb6bfaaf6618acc620320d7220b3af2b23d112d8e9cb1262f3c0d60d183b1ee7f096d12dae42c958418600214d04f5ed6f5e718be35566"
        )
        
        try singleInputHashTest(
            inputHex: "000102030405060708",
            expectedHex: "6a9a090c61b3410aede7ec9138146ceb2c69662f460c3da53c6515c1eb31f41ca3d280e567882f95cf664a94147d78f42cfc714a40d22ef19470e053493508a2"
        )
    }
    
    private func singleInputHashTest(
        inputHex: String,
        expectedHex: String
    ) throws {
        let inputData = try inputHex.hexData()
        
        let actualData = try ThreemaBlake2b.hash(inputData, hashLength: .b64)
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
    
    // blake2b test vectors 11 to 20 from `blake2-kat.json`
    func testDoubleInputHash() throws {
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "06070809",
            expectedHex: "29102511d749db3cc9b4e335fa1f5e8faca8421d558f6a3f3321d50d044a248ba595cfc3efd3d2adc97334da732413f5cbf4751c362ba1d53862ac1e8dabeee8"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a",
            expectedHex: "c97a4779d47e6f77729b5917d0138abb35980ab641bd73a8859eb1ac98c05362ed7d608f2e9587d6ba9e271d343125d40d933a8ed04ec1fe75ec407c7a53c34e"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a0b",
            expectedHex: "10f0dc91b9f845fb95fad6860e6ce1adfa002c7fc327116d44d047cd7d5870d772bb12b5fac00e02b08ac2a0174d0446c36ab35f14ca31894cd61c78c849b48a"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a0b0c",
            expectedHex: "dea9101cac62b8f6a3c650f90eea5bfae2653a4eafd63a6d1f0f132db9e4f2b1b662432ec85b17bcac41e775637881f6aab38dd66dcbd080f0990a7a6e9854fe"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a0b0c0d",
            expectedHex: "441ffaa08cd79dff4afc9b9e5b5620eec086730c25f661b1d6fbfbd1cec3148dd72258c65641f2fca5eb155fadbcabb13c6e21dc11faf72c2a281b7d56145f19"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a0b0c0d0e",
            expectedHex: "444b240fe3ed86d0e2ef4ce7d851edde22155582aa0914797b726cd058b6f45932e0e129516876527b1dd88fc66d7119f4ab3bed93a61a0e2d2d2aeac336d958"
        )
        
        try doubleInputHashTest(
            inputHex1: "000102030405",
            inputHex2: "060708090a0b0c0d0e0f",
            expectedHex: "bfbabbef45554ccfa0dc83752a19cc35d5920956b301d558d772282bc867009168e9e98606bb5ba73a385de5749228c925a85019b71f72fe29b3cd37ca52efe6"
        )
        
        try doubleInputHashTest(
            inputHex1: "00010203040506070809",
            inputHex2: "0a0b0c0d0e0f10",
            expectedHex: "9c4d0c3e1cdbbf485bec86f41cec7c98373f0e09f392849aaa229ebfbf397b22085529cb7ef39f9c7c2222a514182b1effaa178cc3687b1b2b6cbcb6fdeb96f8"
        )
        
        try doubleInputHashTest(
            inputHex1: "00010203040506070809",
            inputHex2: "0a0b0c0d0e0f1011",
            expectedHex: "477176b3bfcbadd7657c23c24625e4d0d674d1868f006006398af97aa41877c8e70d3d14c3bbc9bbcdcea801bd0e1599af1f3eec67405170f4e26c964a57a8b7"
        )
        
        try doubleInputHashTest(
            inputHex1: "00010203040506070809",
            inputHex2: "0a0b0c0d0e0f101112",
            expectedHex: "a78c490eda3173bb3f10dee52f110fb1c08e0302230b85ddd7c11257d92de148785ef00c039c0bb8eb9808a35b2d8c080f572859714c9d4069c5bcaf090e898e"
        )
    }
     
    private func doubleInputHashTest(
        inputHex1: String,
        inputHex2: String,
        expectedHex: String
    ) throws {
        let inputData1 = try inputHex1.hexData()
        let inputData2 = try inputHex2.hexData()

        let actualData = try ThreemaBlake2b.hash(inputData1, inputData2, hashLength: .b64)
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
    
    // Last blake2b test vector with no key from `blake2-kat.json` (line 4605ff)
    func test5InputHash() throws {
        let expectedHex =
            "5b21c5fd8868367612474fa2e70e9cfa2201ffeee8fafab5797ad58fefa17c9b5b107da4a3db6320baaf2c8617d5a51df914ae88da3867c2d41f0cc14fa67928"
                
        let inputData1 = try "000102030405060708090a0b0c".hexData()
        let inputData2 =
            try "0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c"
                .hexData()
        let inputData3 =
            try "4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e"
                .hexData()
        let inputData4 =
            try "8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6"
                .hexData()
        let inputData5 = try "e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfe".hexData()

        let actualData = try ThreemaBlake2b.hash(
            inputData1,
            inputData2,
            inputData3,
            inputData4,
            inputData5,
            hashLength: .b64
        )
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
    
    // MARK: - Keyed hash
    
    // 10 blake2b test vectors from `blake2-kat.json` starting at line 5470
    func testKeyedHash() throws {
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "d85cabc6bd5b1a01a5afd8c6734740da9fd1c1acc6db29bfc8a2e5b668b028b6b3154bfb8703fa3180251d589ad38040ceb707c4bad1b5343cb426b61eaa49c1"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "d62efbec2ca9c1f8bd66ce8b3f6a898cb3f7566ba6568c618ad1feb2b65b76c3ce1dd20f7395372faf28427f61c9278049cf0140df434f5633048c86b81e0399"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f90",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "7c8fdc6175439e2c3db15bafa7fb06143a6a23bc90f449e79deef73c3d492a671715c193b6fea9f036050b946069856b897e08c00768f5ee5ddcf70b7cd6d0e0"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "d85cabc6bd5b1a01a5afd8c6734740da9fd1c1acc6db29bfc8a2e5b668b028b6b3154bfb8703fa3180251d589ad38040ceb707c4bad1b5343cb426b61eaa49c1"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f9091",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "58602ee7468e6bc9df21bd51b23c005f72d6cb013f0a1b48cbec5eca299299f97f09f54a9a01483eaeb315a6478bad37ba47ca1347c7c8fc9e6695592c91d723"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "27f5b79ed256b050993d793496edf4807c1d85a7b0a67c9c4fa99860750b0ae66989670a8ffd7856d7ce411599e58c4d77b232a62bef64d15275be46a68235ff"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f90919293",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "3957a976b9f1887bf004a8dca942c92d2b37ea52600f25e0c9bc5707d0279c00c6e85a839b0d2d8eb59c51d94788ebe62474a791cadf52cccf20f5070b6573fc"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f9091929394",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "eaa2376d55380bf772ecca9cb0aa4668c95c707162fa86d518c8ce0ca9bf7362b9f2a0adc3ff59922df921b94567e81e452f6c1a07fc817cebe99604b3505d38"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "c1e2c78b6b2734e2480ec550434cb5d613111adcc21d475545c3b1b7e6ff12444476e5c055132e2229dc0f807044bb919b1a5662dd38a9ee65e243a3911aed1a"
        )
        
        try keyedHashTest(
            inputHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f90919293949596",
            keyHex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            expectedHex: "8ab48713389dd0fcf9f965d3ce66b1e559a1f8c58741d67683cd971354f452e62d0207a65e436c5d5d8f8ee71c6abfe50e669004c302b31a7ea8311d4a916051"
        )
    }
    
    private func keyedHashTest(
        inputHex: String,
        keyHex: String,
        expectedHex: String
    ) throws {
        let inputData = try inputHex.hexData()
        let keyData = try keyHex.hexData()
        
        let actualData = try ThreemaBlake2b.hash(inputData, key: keyData, hashLength: .b64)
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
    
    // MARK: - Error testing
    
    func testWrongKeySizeError() throws {
        XCTAssertThrowsExpectedError(
            try ThreemaBlake2b
                .deriveKey(from: Data([0x01, 0x02]), with: "Hello", personal: "Word", derivedKeyLength: .b64),
            ThreemaBlake2b.Error.wrongKeySize
        )
    }
    
    func testSaltEmptyError() throws {
        // Key from test vector in `blake2-kat.json` (line 4611)
        let keyData =
            try "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"
                .hexData()
                        
        XCTAssertThrowsExpectedError(
            try ThreemaBlake2b.deriveKey(from: keyData, with: "", personal: Data(), derivedKeyLength: .b64),
            ThreemaBlake2b.Error.saltEmpty
        )
    }
    
    func testSaltTooLongError() throws {
        XCTAssertThrowsExpectedError(
            try ThreemaBlake2b
                .hash(
                    Data([0x01, 0x02]),
                    salt: "NoMoreThan16BytesAreAllowedInHere",
                    personal: "ThreemaBlake2bTests",
                    hashLength: .b64
                ),
            ThreemaBlake2b.Error.saltTooLong
        )
    }
    
    func testPersonalEmptyError() throws {
        XCTAssertThrowsExpectedError(
            try ThreemaBlake2b.hash(Data([0x01, 0x02]), salt: "abc", personal: "", hashLength: .b64),
            ThreemaBlake2b.Error.personalEmpty
        )
    }
    
    func testPersonalTooLongError() throws {
        XCTAssertThrowsExpectedError(
            try ThreemaBlake2b
                .hash(Data([0x01, 0x02]), salt: "abc", personal: "NoMoreThan16BytesAreAllowedInHere", hashLength: .b64),
            ThreemaBlake2b.Error.personalTooLong
        )
    }
    
    // MARK: - Tests to prevent previous bugs
    
    func testDeriveKeyWithPersonal() throws {
        let expectedHex =
            "e7086174eec29d0720482a6ca8bdbde6862cdaff2c23beb4bf534536526c3941a7b164891fc99f499e40bdaefeba1be3b734a521b01eec2abaad4f6fc4324959"
        
        let key = Data(repeating: 0x1, count: 32)
        let salt = "ab"
        let personal = "cd"
        
        let actualData = try ThreemaBlake2b.deriveKey(from: key, with: salt, personal: personal, derivedKeyLength: .b64)
        
        XCTAssertEqual(actualData.hexString, expectedHex)
    }
}

// MARK: - Helper extensions

// Based on https://stackoverflow.com/a/43360864
extension String {
    fileprivate enum DecodingError: Error {
        case oddNumberOfCharacters
    }

    fileprivate func hexData() throws -> Data {
        guard count % 2 == 0 else {
            throw DecodingError.oddNumberOfCharacters
        }
        
        return .init(hexSequence)
    }
    
    private var hexSequence: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else {
                return nil
            }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer {
                startIndex = endIndex
            }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

extension Data {
    fileprivate var hexString: String {
        map { String(format: "%02hhx", $0) }
            .joined()
    }
}

private func XCTAssertThrowsExpectedError<E: Error & Equatable>(
    _ expression: @autoclosure () throws -> some Any,
    _ expectedError: E,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
        XCTAssertNotNil(error as? E)
        XCTAssertEqual(error as? E, expectedError)
    }
}
