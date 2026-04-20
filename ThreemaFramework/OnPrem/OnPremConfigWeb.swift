import Foundation

public struct OnPremConfigWeb: Decodable, Sendable {
    let url: String
    let overrideSaltyRtcHost: String?
    let overrideSaltyRtcPort: Int?
}
