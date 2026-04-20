import Foundation

public struct OnPremLicense: Decodable, Sendable {
    let id: String
    let expires: Date
    let count: Int
}
