import Foundation

struct OnPremConfigDomains: Decodable, Sendable {
    let rules: [OnPremConfigDomain]
}
