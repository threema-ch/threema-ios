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

import CommonCrypto
import Foundation

public enum BytesUtility {
    
    /// Add right padding to source bytes.
    ///
    /// - Parameter source: First bytes
    /// - Parameter pad: Byte for padding
    /// - Parameter length: Length of source + padding
    ///
    /// - Returns: Bytes with source + padding
    public static func padding(_ source: [UInt8], pad: UInt8, length: Int) -> [UInt8] {
        guard source.count <= length else {
            return source
        }
        
        var buffer = Data(bytes: source, count: source.count)
        
        var i = source.count
        while i < length {
            buffer.append(pad)
            i += 1
        }

        return Array(buffer)
    }
    
    /// Generate padding with random length, pad is equal length value.
    ///
    /// - Returns: Data
    public static func paddingRandom() -> Data {
        var paddingLength: UInt8? = NaClCrypto.shared()?.randomBytes(1)?.convert()
        if paddingLength == nil {
            paddingLength = 1
        }
        else if paddingLength! < 1 {
            paddingLength = 1
        }
        
        var padding = Data()
        var padd = 0
        while padd < paddingLength! {
            padding.append(paddingLength!)
            padd = padd + 1
        }
        return padding
    }

    /// Convert data to hex string.
    /// - Parameter data: Data as hex string
    /// - Returns: Hex String
    public static func toHexString(data: Data) -> String {
        toHexString(bytes: Array(data))
    }

    /// Convert bytes to hex string.
    /// - Parameter bytes: Bytes to convert
    /// - Returns: Hex string
    public static func toHexString(bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Convert hex string to bytes.
    /// - Parameter data: Hex string
    /// - Returns: Bytes or nil if Hex string not valid
    public static func toBytes(hexString: String) -> [UInt8]? {
        var hex = hexString
        var bytes = Data()

        while !hex.isEmpty {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])

            guard let int = Scanner(string: c).scanInt32(representation: .hexadecimal) else {
                return nil
            }
            var char = UInt8(int)

            bytes.append(&char, count: 1)
        }

        return Array(bytes)
    }
    
    /// Generate SHA1 hash, uses Apple's CommonCrypto module.
    ///
    /// - Parameter data: Data for hashing
    ///
    /// - Returns: SHA1 hash
    public static func sha1(data: Data) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest
    }
    
    /// Generate random bytes, uses Apple's Security module.
    ///
    /// - Parameter length: Length of bytes
    /// - Returns: Random bytes
    public static func generateRandomBytes(length: Int) -> Data? {
        var keyData = Data(count: length)
        let result = keyData.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, length, ptr.baseAddress!)
        }
        if result == errSecSuccess {
            return keyData
        }
        else {
            return nil
        }
    }
}

extension Data {
    
    enum Endianness {
        case BigEndian
        case LittleEndian
    }
    
    func convert<T: FixedWidthInteger>(at index: Data.Index, endianess: Endianness) -> T {
        let end = index + MemoryLayout<T>.size > count ? count : index + MemoryLayout<T>.size
        let number: T = subdata(in: index..<end).withUnsafeBytes { $0.pointee }
        switch endianess {
        case .BigEndian:
            return number.bigEndian
        case .LittleEndian:
            return number.littleEndian
        }
    }
    
    func convert<T: FixedWidthInteger>(at index: Data.Index = 0) -> T {
        let end = index + MemoryLayout<T>.size > count ? count : index + MemoryLayout<T>.size
        let bytes: [UInt8] = Array(subdata(in: index..<end))
        return bytes.reversed().reduce(0) { result, byte in
            result << 8 | T(byte)
        }
    }
    
    public var hexString: String {
        BytesUtility.toHexString(data: self)
    }
}
