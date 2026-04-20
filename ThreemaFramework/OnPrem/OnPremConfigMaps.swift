import Foundation

public struct OnPremConfigMaps: Decodable, Sendable {
    let poiNamesURL: String
    let poiAroundURL: String
    
    enum CodingKeys: String, CodingKey {
        case poiNamesURL = "poiNamesUrl"
        case poiAroundURL = "poiAroundUrl"
    }
}
