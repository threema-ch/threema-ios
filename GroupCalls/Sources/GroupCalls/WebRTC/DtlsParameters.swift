import Foundation

struct DtlsParameters: Equatable {
    let fingerprint: [UInt8]
    
    func fingerprintToString() -> String {
        fingerprint.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}
