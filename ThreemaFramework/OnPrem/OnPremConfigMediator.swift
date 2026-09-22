import Foundation

struct OnPremConfigMediator: Decodable, Sendable {
    let url: String
    let blob: OnPremConfigBlob
}
