import Foundation

struct Codec {
    let payloadType: UInt8
    let parameters: [UInt64]
    let feedback: [String]?
    let fmtp: [String]?
}
