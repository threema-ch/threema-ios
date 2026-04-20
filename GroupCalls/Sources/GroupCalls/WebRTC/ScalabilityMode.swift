import Foundation

enum ScalabilityMode {
    case L1T3
    
    var temporalLayers: Int {
        switch self {
        case .L1T3:
            3
        }
    }
}
