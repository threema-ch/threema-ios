import Foundation
import AVFoundation
import UIKit
import Photos

/**
 Protocol representation of types of media that asset can provide.
 Image assets will return full image as an image and nil video.
 Video assets will return thumbnail as an image and AVAsset as video.
 */
public protocol MediaProvider {
    func image() -> UIImage?
    func video() -> AVAsset?
    func phasset() -> PHAsset?
}

/**
 Protocol representation of an asset.
 */
protocol PPAsset: MediaProvider {
    associatedtype AssetType
    var asset: AssetType { get }
}

/**
 Default implementations of MediaProviding protocol methods.
 */
extension PPAsset {
    public func image() -> UIImage? {
        var result: UIImage?
        
        if let image = asset as? UIImage {
            result = image
        } else if let avasset = asset as? AVAsset {
            let imageGenerator = AVAssetImageGenerator(asset: avasset)
            imageGenerator.appliesPreferredTrackTransform = true
            var time = avasset.duration
            time.value = min(time.value, 1)
            
            if let imageRef = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
                result = UIImage(cgImage: imageRef)
            }
        }
        
        return result
    }
    
    public func video() -> AVAsset? {
        var result: AVAsset?
        
        if let avasset = asset as? AVAsset {
            result = avasset
        }
        
        return result
    }
    
    public func phasset() -> PHAsset? {
        var result: PHAsset?
        if let pa = asset as? PHAsset {
            result = pa
        }
        return result
    }
        
    public func phassetIsImage() -> Bool {
        if let asset = self.phasset() {
            if asset.mediaType == .image {
                return true
            }
        }
        return false
    }
}

/**
 Conforming asset types.
 */
extension UIImage: PPAsset {
    internal var asset: UIImage {
        return self
    }
    
    func resizedImage(newSize: CGSize) -> UIImage {
        // Guard newSize is different
        guard self.size != newSize else { return self }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        self.draw(in: CGRect(x: 0.0, y: 0.0, width: newSize.width, height: newSize.height))
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func resizedImageWithinRect(rectSize: CGSize) -> UIImage {
        let widthFactor = size.width / rectSize.width
        let heightFactor = size.height / rectSize.height
        
        var resizeFactor = widthFactor
        if size.height > size.width {
            resizeFactor = heightFactor
        }
        
        let newSize = CGSize(width: size.width/resizeFactor, height: size.height/resizeFactor)
        let resized = resizedImage(newSize: newSize)
        return resized
    }
}
extension AVAsset: PPAsset {
    internal var asset: AVAsset {
        return self
    }
}
extension PHAsset: PPAsset {
    internal var asset: PHAsset {
        return self
    }
    
    func fetchThumbnail(_ size: CGSize, completeBlock: @escaping (_ image: UIImage?, _ info: [AnyHashable: Any]?) -> Void) {
        PHCachingImageManager().requestImage(for: asset, targetSize: CGSize(width: 220.0, height: 220.0), contentMode: .aspectFit, options: nil, resultHandler: { (image, dict) in
            completeBlock(image, dict)
        })
    }
    
    func fetchImageForAsset(size: CGSize, options: PHImageRequestOptions?, contentMode: PHImageContentMode, completeBlock: @escaping (_ image: UIImage?, _ info: [AnyHashable: Any]?) -> Void) {
        PHCachingImageManager().requestImage(for: asset, targetSize: size, contentMode: contentMode, options: options, resultHandler: { image, info in
            if let isInCloud = info?[PHImageResultIsInCloudKey] as AnyObject?
                , image == nil && isInCloud.boolValue {
                options?.isNetworkAccessAllowed = true
                self.fetchImageForAsset(size: size, options: options, contentMode: contentMode, completeBlock: completeBlock)
            } else {
                completeBlock(image, info)
            }
        })
    }
}

/**
 Type erasing wrapper around PPAsset.
 Covariance is not supported as of Swift 3.
 */
struct AnyPPAsset<AssetType>: PPAsset {
    let base: AssetType
    
    init<A : PPAsset>(_ base: A) where A.AssetType == AssetType {
        self.base = base.asset
    }
    
    internal var asset: AssetType {
        return base
    }
}
