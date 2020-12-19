import UIKit
import AVFoundation

/**
 Cell representing live camera feed in Assets Collection Controller.
 */
class PPLiveCameraCell: UICollectionViewCell {

    func set(layer: AVCaptureVideoPreviewLayer) {
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
    }

    override func layoutSubviews() {
        self.layer.sublayers?[0].frame = bounds
    }
}

extension PPLiveCameraCell: PPReusableView {}
