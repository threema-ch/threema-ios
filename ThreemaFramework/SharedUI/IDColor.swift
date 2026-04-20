import CocoaLumberjackSwift
import CryptoKit
import Foundation

enum IDColor {
    
    /// Get the ID Color for the passed data
    /// - Parameter data: Data to get ID color for. We assume that is quite small.
    /// - Returns: Dynamic ID Color for `data`
    static func forData(_ data: Data) -> UIColor {
        guard !UIAccessibility.isDarkerSystemColorsEnabled else {
            // Use primary color when increase contrast is activated
            return .primary
        }
        
        guard let firstByte = firstSHA256Byte(for: data) else {
            // We don't expect this to ever happen
            DDLogWarn("Unable to get first byte for ID Color")
            return .primary
        }
        
        return UIColor.IDColor.forByte(firstByte)
    }
    
    /// Cache first byte calculation
    ///
    /// As it is independent of the colors it doesn't need to be reset at any point.
    private static var cache = [Data: UInt8]()
    
    private static func firstSHA256Byte(for data: Data) -> UInt8? {
        if let firstByte = cache[data] {
            return firstByte
        }
        
        let idHash = SHA256.hash(data: data)
        
        // Thats the "easiest" way we found to get a first byte of the digest
        // Another way would be to use `prefix()` with a `map()` to `UInt8` and then take the first element.
        // (i.e. `idHash.prefix(1).map({ $0 as UInt8 }).first`)
        var iterator = idHash.makeIterator()
        let firstByte = iterator.next()
        
        cache[data] = firstByte
        return firstByte
    }
}
