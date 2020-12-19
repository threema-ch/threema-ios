import UIKit
import PhotosUI

/**
 Cell representing photo asset in Assets Collection Controller.
 */
class PPPhotoViewCell: PPCheckedViewCell {
    
    var asset:PHAsset?
    var calcSize:CGSize?
    
    func set(_ image: PHAsset) {
        if asset != image || calcSize != calcNewSizeForAsset() {
            self.asset = image
            self.calcSize = calcNewSizeForAsset()
            let options: PHImageRequestOptions = PHImageRequestOptions.init()
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            PHImageManager.default().requestImage(for: image, targetSize: self.calcSize!, contentMode: .aspectFit, options: options) { (loadedImage, info) in
                if loadedImage != nil {
                    let photo = UIImageView( image: loadedImage)
                    photo.contentMode = .scaleAspectFit
                    photo.clipsToBounds = true
                    self.backgroundView = photo
                } else {
                    let photo = UIImageView( image: nil)
                    photo.contentMode = .scaleAspectFit
                    photo.clipsToBounds = true
                    photo.backgroundColor = UIColor.black
                    self.backgroundView = photo
                }
            }
        }
        self.setupCheckmark()
    }
    
    func calcNewSizeForAsset() -> CGSize {
        let widthFactor = CGFloat((asset?.pixelWidth)!) / self.frame.size.width
        let heightFactor = CGFloat((asset?.pixelHeight)!) / self.frame.size.height
        
        var resizeFactor = widthFactor
        if CGFloat((asset?.pixelHeight)!) > CGFloat((asset?.pixelWidth)!) {
            resizeFactor = heightFactor
        }
        
        return CGSize(width: (CGFloat((asset?.pixelWidth)!)/resizeFactor) * 3.0, height: (CGFloat((asset?.pixelHeight)!)/resizeFactor) * 3.0)
    }
}
