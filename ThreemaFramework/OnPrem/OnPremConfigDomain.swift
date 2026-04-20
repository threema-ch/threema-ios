import Foundation

public struct OnPremConfigDomain: Decodable, Sendable {
    let spkis: [OnPremConfigSpkis]
    let fqdn: String
    let matchMode: String
}
