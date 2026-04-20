import Foundation

public struct OnPremConfigMediator: Decodable, Sendable {
    let url: String
    let blob: OnPremConfigBlob
}
