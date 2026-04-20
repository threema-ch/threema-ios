import Foundation

extension FixedWidthInteger {
    /// Convert into data stored as little endian
    public var littleEndianData: Data {
        // Inspired by https://www.hackingwithswift.com/forums/swift/how-do-i-get-a-uint32-into-a-data/8802/8803
        var littleEndianInt = littleEndian
        return Data(bytes: &littleEndianInt, count: MemoryLayout<Self>.size)
    }
}
