import Foundation

// Based on https://github.com/apple/swift-crypto/blob/d1c6b70f7c5f19fb0b8750cb8dcdf2ea6e2d8c34/Sources/Crypto/Util/Zeroization.swift
extension Data {
    mutating func zeroize() {
        _ = withUnsafeMutableBytes {
            memset_s($0.baseAddress!, $0.count, 0, $0.count)
        }
    }
}
