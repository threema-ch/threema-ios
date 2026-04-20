import Foundation

public struct OnPremConfigChat: Decodable, Sendable {
    let hostname: String
    let ports: [Int]
    let publicKey: Data
}
