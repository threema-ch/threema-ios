import Foundation

struct OnPremConfigDomain: Decodable, Sendable {
    let spkis: [OnPremConfigSpkis]
    let fqdn: String
    let matchMode: String
}
