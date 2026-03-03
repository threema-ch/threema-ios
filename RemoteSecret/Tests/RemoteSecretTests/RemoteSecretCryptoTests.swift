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
import Testing
@testable import RemoteSecret

@Suite("Remote Secret Crypto")
struct RemoteSecretCryptoTests {
    
    // MARK: - Encrypt / Decrypt

    @Suite("Encrypt / Decrypt")
    struct EncryptDecrypt {
        let remoteSecret = RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        
        // MARK: Data
        
        @Test func encryptDecryptData() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)
                        
            let data = Data(repeating: 2, count: 100)
            let encryptedData = remoteSecretCrypto.encrypt(data)
            
            #expect(data != encryptedData)
            #expect(data.count < encryptedData.count)

            let decryptedData: Data = remoteSecretCrypto.decrypt(encryptedData)
            #expect(data == decryptedData)
        }
        
        @Test func decryptData() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(
                remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
            )

            let data = Data(repeating: 2, count: 8)
            // swiftformat:disable:next all
            let encryptedData = Data([8, 45, 108, 111, 228, 246, 67, 130, 90, 36, 75, 165, 209, 110, 93, 163, 30, 139, 159, 216, 246, 147, 20, 27, 110, 168, 25, 55, 110, 66, 5, 60, 50, 240, 170, 107, 33, 80, 235, 158, 248, 37, 2, 129, 252, 75, 149, 82])
            let decryptedData: Data = remoteSecretCrypto.decrypt(encryptedData)
            #expect(data == decryptedData)
        }
        
        // MARK: Empty data
        
        @Test func encryptDecryptEmptyData() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)
                        
            let data = Data()
            let encryptedData = remoteSecretCrypto.encrypt(data)
            
            #expect(data != encryptedData)
            #expect(data.count < encryptedData.count)

            let decryptedData: Data = remoteSecretCrypto.decrypt(encryptedData)
            #expect(data == decryptedData)
        }
                
        @Test func decryptEmptyData() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(
                remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
            )

            let data = Data()
            // swiftformat:disable:next all
            let encryptedData = Data([105, 168, 169, 177, 242, 255, 105, 98, 188, 67, 228, 183, 233, 204, 7, 146, 24, 1, 179, 236, 166, 214, 175, 182, 125, 209, 2, 85, 69, 190, 60, 57, 135, 147, 54, 126, 152, 120, 253, 166])
            let decryptedData: Data = remoteSecretCrypto.decrypt(encryptedData)
            #expect(data == decryptedData)
        }
        
        // MARK: String
        
        @Test func encryptDecryptString() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let string = "Test String"
            
            let encryptedString = remoteSecretCrypto.encrypt(string)
            let decryptedString: String = remoteSecretCrypto.decrypt(encryptedString)
            
            #expect(decryptedString == string)
        }
        
        // MARK: Int16
        
        @Test func encryptDecryptInt16() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let int = Int16.max
            
            let encryptedInt = remoteSecretCrypto.encrypt(int)
            let decryptedInt: Int16 = remoteSecretCrypto.decrypt(encryptedInt)
            
            #expect(decryptedInt == int)
        }
        
        // MARK: Int32
        
        @Test func encryptDecryptInt32() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let int = Int32.max
            
            let encryptedInt = remoteSecretCrypto.encrypt(int)
            let decryptedInt: Int32 = remoteSecretCrypto.decrypt(encryptedInt)
            
            #expect(decryptedInt == int)
        }
        
        // MARK: Int64
        
        @Test func encryptDecryptInt64() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let int = Int64.max
            
            let encryptedInt = remoteSecretCrypto.encrypt(int)
            let decryptedInt: Int64 = remoteSecretCrypto.decrypt(encryptedInt)
            
            #expect(decryptedInt == int)
        }
        
        // MARK: Double
        
        @Test func encryptDecryptDouble() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let double = Double.greatestFiniteMagnitude
            
            let encryptedDouble = remoteSecretCrypto.encrypt(double)
            let decryptedDouble: Double = remoteSecretCrypto.decrypt(encryptedDouble)
            
            #expect(decryptedDouble == double)
        }
        
        // MARK: Float
        
        @Test func encryptDecryptFloat() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let float = Float.greatestFiniteMagnitude
            
            let encryptedFloat = remoteSecretCrypto.encrypt(float)
            let decryptedFloat: Float = remoteSecretCrypto.decrypt(encryptedFloat)
            
            #expect(decryptedFloat == float)
        }
        
        // MARK: Date
        
        @Test func encryptDecryptDate() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let date = Date.distantPast
            
            let encryptedDate = remoteSecretCrypto.encrypt(date)
            let decryptedDate: Date = remoteSecretCrypto.decrypt(encryptedDate)
            
            #expect(decryptedDate == date)
        }
        
        // MARK: Bool
        
        @Test func encryptDecryptBool() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: remoteSecret)

            let bool = true
            
            let encryptedBool = remoteSecretCrypto.encrypt(bool)
            let decryptedBool: Bool = remoteSecretCrypto.decrypt(encryptedBool)
            
            #expect(decryptedBool == bool)
        }
    }
    
    // MARK: - Encode / Decode
    
    @Suite("Encode / Decode")
    struct EncodeDecode {
        let remoteSecretCrypto = try! RemoteSecretCrypto(
            remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        )

        // MARK: String
        
        @Test func encodeDecodeString() async throws {
            let stringLong = String("Random _Weird_ String to \n\r Encode ✌🏻.")
            let encodedLong = remoteSecretCrypto.coder.encode(stringLong)
            let decodedLong: String = remoteSecretCrypto.coder.decode(encodedLong)
            #expect(decodedLong == stringLong)
            
            let stringEmpty = String("")
            let encodedEmpty = remoteSecretCrypto.coder.encode(stringEmpty)
            let decodedEmpty: String = remoteSecretCrypto.coder.decode(encodedEmpty)
            #expect(decodedEmpty == stringEmpty)
        }
        
        @Test func assertCodingDidNotChangeString() async throws {
            let string = "Test"
            let prevEncoded = Data([84, 101, 115, 116])
            
            let encoded = remoteSecretCrypto.coder.encode(string)
            #expect(encoded == prevEncoded)

            let decoded: String = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == string)
        }
        
        // MARK: Int16
        
        @Test func encodeDecodeInt16() async throws {
            let int16Max = Int16.max
            let encodedMax = remoteSecretCrypto.coder.encode(int16Max)
            let decodedMax: Int16 = remoteSecretCrypto.coder.decode(encodedMax)
            #expect(decodedMax == int16Max)
            
            let int16Min = Int16.min
            let encodedMin = remoteSecretCrypto.coder.encode(int16Min)
            let decodedMin: Int16 = remoteSecretCrypto.coder.decode(encodedMin)
            #expect(decodedMin == int16Min)
        }
        
        @Test func assertCodingDidNotChangeInt16() async throws {
            let int16: Int16 = 256
            let prevEncoded = Data(bytes: [0x0100], count: 2)
            
            let encoded = remoteSecretCrypto.coder.encode(int16)
            #expect(encoded == prevEncoded)

            let decoded: Int16 = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == int16)
        }
        
        // MARK: Int32

        @Test func encodeDecodeInt32() async throws {
            let int32Max = Int32.max
            let encodedMax = remoteSecretCrypto.coder.encode(int32Max)
            let decodedMax: Int32 = remoteSecretCrypto.coder.decode(encodedMax)
            #expect(decodedMax == int32Max)
            
            let int32Min = Int32.min
            let encodedMin = remoteSecretCrypto.coder.encode(int32Min)
            let decodedMin: Int32 = remoteSecretCrypto.coder.decode(encodedMin)
            #expect(decodedMin == int32Min)
        }
        
        @Test func assertCodingDidNotChangeInt32() async throws {
            let int32: Int32 = 256
            let prevEncoded = Data(bytes: [0x0000_0100], count: 4)
            
            let encoded = remoteSecretCrypto.coder.encode(int32)
            #expect(encoded == prevEncoded)
            
            let decoded: Int32 = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == int32)
        }
        
        // MARK: Int64
        
        @Test func encodeDecodeInt64() async throws {
            let int64Max = Int64.max
            let encodedMax = remoteSecretCrypto.coder.encode(int64Max)
            let decodedMax: Int64 = remoteSecretCrypto.coder.decode(encodedMax)
            #expect(decodedMax == int64Max)
            
            let int64Min = Int64.min
            let encodedMin = remoteSecretCrypto.coder.encode(int64Min)
            let decodedMin: Int64 = remoteSecretCrypto.coder.decode(encodedMin)
            #expect(decodedMin == int64Min)
        }
        
        @Test func assertCodingDidNotChangeInt64() async throws {
            let int64: Int64 = 256
            let prevEncoded = Data(bytes: [0x0000_0000_0000_0100], count: 8)
            
            let encoded = remoteSecretCrypto.coder.encode(int64)
            #expect(encoded == prevEncoded)
            
            let decoded: Int64 = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == int64)
        }
        
        // MARK: Double
        
        @Test func encodeDecodeDouble() async throws {
            let doubleMax = Double.infinity
            let encodedMax = remoteSecretCrypto.coder.encode(doubleMax)
            let decodedMax: Double = remoteSecretCrypto.coder.decode(encodedMax)
            #expect(decodedMax == doubleMax)
            
            let doubleMin = -Double.infinity
            let encodedMin = remoteSecretCrypto.coder.encode(doubleMin)
            let decodedMin: Double = remoteSecretCrypto.coder.decode(encodedMin)
            #expect(decodedMin == doubleMin)
        }
        
        @Test func assertCodingDidNotChangeDouble() async throws {
            let double = 256.256
            let prevEncoded = Data(bytes: [0x4070_0418_9374_BC6A], count: 8)
            
            let encoded = remoteSecretCrypto.coder.encode(double)
            #expect(encoded == prevEncoded)
            
            let decoded: Double = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == double)
        }
        
        // MARK: Float

        @Test func encodeDecodeFloat() async throws {
            let floatMax = Float.infinity
            let encodedMax = remoteSecretCrypto.coder.encode(floatMax)
            let decodedMax: Float = remoteSecretCrypto.coder.decode(encodedMax)
            #expect(decodedMax == floatMax)
            
            let floatMin = -Float.infinity
            let encodedMin = remoteSecretCrypto.coder.encode(floatMin)
            let decodedMin: Float = remoteSecretCrypto.coder.decode(encodedMin)
            #expect(decodedMin == floatMin)
        }
        
        @Test func assertCodingDidNotChangeFloat() async throws {
            let float: Float = 256.256
            let prevEncoded = Data(bytes: [0x4380_20C5], count: 4)
            
            let encoded = remoteSecretCrypto.coder.encode(float)
            #expect(encoded == prevEncoded)
            
            let decoded: Float = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == float)
        }
        
        // MARK: Date
        
        @Test func encodeDecodeDate() async throws {
            let datePast = Date.distantPast
            let encodedPast = remoteSecretCrypto.coder.encode(datePast)
            let decodedPast: Date = remoteSecretCrypto.coder.decode(encodedPast)
            #expect(decodedPast == datePast)
            
            let dateFuture = Date.distantFuture
            let encodedFuture = remoteSecretCrypto.coder.encode(dateFuture)
            let decodedFuture: Date = remoteSecretCrypto.coder.decode(encodedFuture)
            #expect(decodedFuture == dateFuture)
        }
        
        @Test func assertCodingDidNotChangeDate() async throws {
            let date = Date(timeIntervalSince1970: 100)
            let prevEncoded = Data([0, 0, 0, 0, 0, 0, 89, 64])
            
            let encoded = remoteSecretCrypto.coder.encode(date)
            #expect(encoded == prevEncoded)
            
            let decoded: Date = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == date)
        }
        
        // MARK: - Bool
        
        @Test func encodeDecodeBool() async throws {
            let boolTrue = true
            let encodedTrue = remoteSecretCrypto.coder.encode(boolTrue)
            let decodedTrue: Bool = remoteSecretCrypto.coder.decode(encodedTrue)
            #expect(decodedTrue == boolTrue)
            
            let boolFalse = false
            let encodedFalse = remoteSecretCrypto.coder.encode(boolFalse)
            let decodedFalse: Bool = remoteSecretCrypto.coder.decode(encodedFalse)
            #expect(decodedFalse == boolFalse)
        }
        
        @Test func assertCodingDidNotChangeBool() async throws {
            let bool = true
            let prevEncoded = Data([1, 0, 0, 0, 0, 0, 0, 0])
            
            let encoded = remoteSecretCrypto.coder.encode(bool)
            #expect(encoded == prevEncoded)

            let decoded: Bool = remoteSecretCrypto.coder.decode(prevEncoded)
            #expect(decoded == bool)
        }
    }
    
    @Suite("Helpers")
    struct Helpers {
        @Test func concatenate() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(
                remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
            )

            let nonce = Data([1, 2, 3])
            var data = Data([4, 5, 6])
            let tag = Data([7, 8, 9])
            let result = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])
            
            remoteSecretCrypto.concatenate(nonce: nonce, data: &data, tag: tag)
            
            #expect(data == result)
        }
        
        @Test func split() async throws {
            let remoteSecretCrypto = try RemoteSecretCrypto(
                remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
            )

            let nonce = Data(repeating: 1, count: RemoteSecretCrypto.nonceLength)
            var data = Data(repeating: 2, count: 100_000)
            let tag = Data(repeating: 3, count: RemoteSecretCrypto.tagLength)
            
            remoteSecretCrypto.concatenate(nonce: nonce, data: &data, tag: tag)
            
            let resultData = Data(repeating: 2, count: 100_000)
            let result = (nonce, tag)
            
            let split = remoteSecretCrypto.split(data: data)
            
            #expect(split == result)
            #expect(data[RemoteSecretCrypto.nonceLength..<data.count - RemoteSecretCrypto.tagLength] == resultData)
        }
    }
}
