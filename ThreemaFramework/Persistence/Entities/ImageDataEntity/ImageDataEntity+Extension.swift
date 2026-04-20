import Foundation
import UIKit

extension ImageDataEntity {
    @objc public func caption() -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        guard let metaData: NSDictionary = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) else {
            return nil
        }
        
        guard let tiffData: NSDictionary = metaData.object(forKey: kCGImagePropertyTIFFDictionary) as? NSDictionary
        else {
            return nil
        }
        
        return tiffData.object(forKey: kCGImagePropertyTIFFArtist) as? String
    }
    
    @objc public func uiImage() -> UIImage? {
        UIImage(data: data)
    }
}
