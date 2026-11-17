extension MediaConverter {
    
    @available(*, deprecated, message: "Use downscaleImage(image:toSize:traitCollection:) instead")
    public static func downscaleImage(image: UIImage, toSize targetSize: CGSize) -> UIImage {
        downscaleImage(image: image, toSize: targetSize, traitCollection: UITraitCollection.current)
    }
    
    public static func downscaleImage(
        image: UIImage,
        toSize targetSize: CGSize,
        traitCollection: UITraitCollection
    ) -> UIImage {
        downscaleImage(image: image, toSize: targetSize, scale: traitCollection.displayScale)
    }
    
    /// - Parameter scale: Display scale of the target. `0.0` falls back to the main screen scale, which is wrong
    ///   in multi-window environments: pass the scale of the trait collection the image is displayed in instead
    public static func downscaleImage(image: UIImage, toSize targetSize: CGSize, scale: CGFloat) -> UIImage {
        let actualScaleFactor = (scale == 0.0) ? UIScreen.main.scale : scale
        let size = image.size
        let imageScaleFactor = image.scale
        let imagePixelSize = CGSizeMake(size.width * imageScaleFactor, size.height * imageScaleFactor)
        
        let requiredMinPixelSize = CGSizeMake(
            targetSize.width * actualScaleFactor,
            targetSize.height * actualScaleFactor
        )
        let canBeDownscaled = (requiredMinPixelSize.width < imagePixelSize.width) &&
            (requiredMinPixelSize.height < imagePixelSize.height)
        
        if !canBeDownscaled {
            return image
        }
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let downscaledImageSize: CGSize =
            if widthRatio > heightRatio {
                CGSizeMake(size.width * widthRatio, size.height * widthRatio)
            }
            else {
                CGSizeMake(size.width * heightRatio, size.height * heightRatio)
            }
        
        let imageRect: CGRect
        if CGSizeEqualToSize(downscaledImageSize, targetSize) {
            imageRect = CGRectMake(0, 0, targetSize.width, targetSize.height)
        }
        else {
            let xDiff = (downscaledImageSize.width > targetSize.width) ? 0.5 *
                (downscaledImageSize.width - targetSize.width) : 0.0
            let yDiff = (downscaledImageSize.height > targetSize.height) ? 0.5 *
                (downscaledImageSize.height - targetSize.height) : 0.0
            imageRect = CGRectMake(-xDiff, -yDiff, downscaledImageSize.width, downscaledImageSize.height)
        }
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        image.draw(in: imageRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
