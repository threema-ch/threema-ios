import Foundation
import ThreemaMacros

extension LocationMessageEntity {
    public var formattedCoordinates: String {
        guard let latitude = latitude as? Double, let longitude = longitude as? Double else {
            return #localize("location")
        }
        return "\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))"
    }
}
