import Foundation
import ThreemaEssentials

public final class DHSessionID: CustomStringConvertible, Equatable, Comparable {
    static let dhSessionIDLength = 16
    let value: Data
    
    init() {
        self.value = BytesUtility.generateRandomBytes(length: DHSessionID.dhSessionIDLength)!
    }
    
    init(value: Data) throws {
        if value.count != DHSessionID.dhSessionIDLength {
            throw ForwardSecurityError.invalidSessionIDLength
        }
        self.value = value
    }
    
    public var description: String {
        BytesUtility.toHexString(data: value)
    }
    
    public static func == (lhs: DHSessionID, rhs: DHSessionID) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: DHSessionID, rhs: DHSessionID) -> Bool {
        let alhs = [UInt8](lhs.value)
        let blhs = [UInt8](rhs.value)
        for i in 0..<alhs.count {
            if alhs[i] < blhs[i] {
                return true
            }
            else if alhs[i] > blhs[i] {
                return false
            }
        }
        return false
    }
}
