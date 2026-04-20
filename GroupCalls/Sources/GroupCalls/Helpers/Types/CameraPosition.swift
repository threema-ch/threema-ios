import AVFoundation
import Foundation

enum CameraPosition {
    case front
    case back
    
    var avDevicePosition: AVCaptureDevice.Position {
        switch self {
        case .front:
            .front
        case .back:
            .back
        }
    }
}
