import Foundation
import ThreemaProtocols

extension AbstractMessage {
    var minimumRequiredForwardSecurityVersion: CspE2eFs_Version? {
        let version = CspE2eFs_Version(rawValue: Int(self.minimumRequiredForwardSecurityVersion().rawValue))
        
        if case .UNRECOGNIZED = version {
            return nil
        }
        else if version == .unspecified {
            return nil
        }
        
        return version
    }
}
