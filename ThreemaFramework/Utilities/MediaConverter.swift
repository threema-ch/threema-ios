//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

extension MediaConverter {
    
    public static func downscaleImage(image: UIImage, toSize targetSize: CGSize, scale: CGFloat = 0.0) -> UIImage {
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
