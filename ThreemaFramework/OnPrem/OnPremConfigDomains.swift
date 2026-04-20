import Foundation

public struct OnPremConfigDomains: Decodable, Sendable {
    let rules: [OnPremConfigDomain]
}
