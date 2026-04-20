import Foundation
import ThreemaProtocols

extension CspE2eFs_Version: CustomStringConvertible {
    public var description: String {
        let lsb = rawValue & 0xFF
        let msb = (rawValue >> 8) & 0xFF
        
        return "\(msb).\(lsb)"
    }
}
