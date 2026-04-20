import Foundation
import ThreemaProtocols

extension CspE2eFs_VersionRange: CustomStringConvertible {
    public var description: String {
        if let minVersion = CspE2eFs_Version(rawValue: Int(min)),
           let maxVersion = CspE2eFs_Version(rawValue: Int(max)) {
            "{min=\(minVersion), max=\(maxVersion)}"
        }
        else {
            "{min=\(min), max=\(max)}"
        }
    }
}
