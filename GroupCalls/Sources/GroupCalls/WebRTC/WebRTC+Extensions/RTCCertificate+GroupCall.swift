import CocoaLumberjackSwift
import Foundation
import WebRTC

extension RTCCertificate {
    /// Hex encoded fingerprint of the DER representation
    var groupCallFingerprint: Data? {
        let internalFingerprint = fingerprint
        
        guard let reg = try? NSRegularExpression(pattern: "^sha-256 (?<hex>([0-9a-zA-Z]{2}:?){32})$") else {
            DDLogError("[GroupCall] Unable to initialize Regex for fingerprint")
            return nil
        }
        
        let matches = reg.matches(
            in: internalFingerprint,
            range: NSRange(location: 0, length: internalFingerprint.count)
        )
        
        var actualFingerPrint: String?
        
        if let match = matches.first {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: internalFingerprint) {
                actualFingerPrint = String(internalFingerprint[swiftRange])
            }
        }
        
        guard let actualFingerPrint else {
            DDLogError("[GroupCall] No matches found for fingerprint")
            return nil
        }
        
        guard let certificateBytes = actualFingerPrint.replacingOccurrences(of: ":", with: "").hexadecimal else {
            DDLogError("[GroupCall] Unable to convert fingerprint to hex representation")
            return nil
        }
        
        return certificateBytes
    }
}
