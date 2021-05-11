//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

import Foundation
import CoreServices
import PromiseKit
import CocoaLumberjackSwift

@objc public class ImageURLSenderItemCreator : NSObject {
    
    static let kImageSizeSmall : CGFloat  =   640
    static let kImageSizeMedium: CGFloat  =  1024
    static let kImageSizeLarge : CGFloat  =  1600
    static let kImageSizeXLarge : CGFloat =  2592
    static let kImageSizeOriginal: CGFloat = 0
    
    private var userSettingsImageSize : String
    
    /// Initialisation with the image scale settings chosen by the user
    public override init() {
        guard let settings = UserSettings.shared() else {
            self.userSettingsImageSize = "medium"
            return
        }
        self.userSettingsImageSize = settings.imageSize
    }
    
    /// Initialisation with a given scale setting. Should only be used for testing.
    /// - Parameter userSettingsImageSize: Can be set to any of the image sizes returned by imageSizes()
    @objc init(with overrideUserSettingsSizeSize : String, forceSize : Bool) {
        if UserSettings.shared()?.imageSize != nil && !forceSize {
            let settingsImageSize = ImageURLSenderItemCreator.getImageSizeForString(size: UserSettings.shared()!.imageSize)
            let inputImageSize = ImageURLSenderItemCreator.getImageSizeForString(size: overrideUserSettingsSizeSize)
            self.userSettingsImageSize = (settingsImageSize != 0 && settingsImageSize <= inputImageSize) ? UserSettings.shared()!.imageSize : overrideUserSettingsSizeSize
        } else {
            self.userSettingsImageSize = overrideUserSettingsSizeSize
        }
        
        super.init()
    }
    
    /// Create an URLSenderItem from an image represented as Data.
    /// GIFs and PNGs can be rendered as Sticker type.
    /// The image data will not be converted
    /// - Parameters:
    ///   - image: Must be jpg, gif or png image
    ///   - uti: The UTI of the image in image. The UTI must be validated before passing it into this function
    /// - Returns: An URLSenderItem representing the image
    @objc public func senderItem(from image : Data, uti : String) -> URLSenderItem? {
        guard let img = UIImage(data: image) else {
            return nil
        }
        
        let maxSize: CGFloat = imageMaxSize(nil)
                
        var imageData : Data?
        var renderType : NSNumber = 1
        var finalUti : String = uti
        
        if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: uti)) {
            renderType = 2
        } else if ImageURLSenderItemCreator.isPNGSticker(image: img, uti: uti) {
            renderType = 2

            guard let convData = MediaConverter.scaleImageData(to: image, toMaxSize: maxSize, useJPEG: false) else {
                return nil
            }
            imageData = convData
        } else {
            guard let convJpgData = MediaConverter.scaleImageData(to: image, toMaxSize: maxSize, useJPEG: true) else {
                return nil
            }
            imageData = convJpgData
            finalUti = kUTTypeJPEG as String
        }
        
        let mimeType = UTIConverter.mimeType(fromUTI: finalUti)
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + "." + UTIConverter.preferedFileExtension(forMimeType: mimeType)
        
        return URLSenderItem(data: imageData ?? image,
                             fileName: filename,
                             type: finalUti,
                             renderType: renderType,
                             sendAsFile: true)
    }
    
    @objc public func senderItem(url : URL, uti : String) -> URLSenderItem? {
        let maxSize: CGFloat = imageMaxSize()
                
        var imageData : Data?
        var renderType : NSNumber = 1
        var finalUti : String = uti
        
        if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: uti)) {
            renderType = 2
            do {
                imageData = try Data(contentsOf: url)
            } catch {
                DDLogError(error.localizedDescription)
                return nil
            }
        } else {
            guard let scaledImage = MediaConverter.scaleImageUrl(url, toMaxSize: maxSize) else {
                return nil
            }
            
            if ImageURLSenderItemCreator.isPNGSticker(image: scaledImage, uti: uti) {
                renderType = 2
                imageData = MediaConverter.pngRepresentation(for: scaledImage)
            } else {
                guard let convJpgData = MediaConverter.jpegRepresentation(for: scaledImage) else {
                    return nil
                }
                imageData = convJpgData
                finalUti = kUTTypeJPEG as String
            }
        }
        
        let mimeType = UTIConverter.mimeType(fromUTI: finalUti)
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + "." + UTIConverter.preferedFileExtension(forMimeType: mimeType)
        
        return URLSenderItem(data: imageData,
                             fileName: filename,
                             type: finalUti,
                             renderType: renderType,
                             sendAsFile: true)
    }
    
    /// Create an URLSenderItem from an image represented by an URL.
    /// The image may be converted to jpeg if it is not of a valid type e.g. HEIC will be converted to jpg. PNG will never be converted to jpg.
    /// - Parameter url: The URL pointing to a valid image in any format readable by UIImage and convertable by UIImage.jpegData.
    /// - Returns: An URLSenderItem for the image
    @objc public func senderItem(from url : URL) -> URLSenderItem? {
        guard let scheme = url.scheme else {
            return nil
        }
        if (scheme != "file") || !FileManager.default.fileExists(atPath: url.relativePath) {
            return nil
        }
        
        guard var uti = UTIConverter.uti(forFileURL: url) else {
            return nil
        }
        
        do {
            var data = try Data(contentsOf: url)
            if !ImageURLSenderItemCreator.isAllowedUTI(uti: uti) {
                guard let image = UIImage(data: data) else {
                    return nil
                }
                guard let imageData = MediaConverter.jpegRepresentation(for: image) else {
                    return nil
                }
                data = imageData
                uti = kUTTypeJPEG as String
                
                guard let item = self.senderItem(from: data, uti: uti) else {
                    DDLogError("Could not create item")
                    return nil
                }
                return item
            } else {
                guard let item = self.senderItem(url: url, uti: uti) else {
                    DDLogError("Could not create item")
                    return nil
                }
                return item
            }
        } catch {
            DDLogError(error.localizedDescription)
        }
        return nil
    }
    
    /// Create an URLSenderItem from an image represented by an UIImage object
    /// The image will always be converted to jpg
    /// - Parameter image: An image
    /// - Returns: An URLSenderItem for the image
    @available(*, deprecated, message: "Is only available for to support legacy Objective-C code. Please use any of the other functions")
    @objc func senderItem(fromImage image : UIImage) -> URLSenderItem? {
        guard let image = MediaConverter.scale(image, toMaxSize: imageMaxSize(image)) else {
            return nil
        }
        
        let data = MediaConverter.jpegRepresentation(for: image)!
        let type = kUTTypeJPEG as String
        let renderType : NSNumber = 1
        
        let ext = UTIConverter.preferedFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: type))!
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + ext
        
        return URLSenderItem(data: data,
                             fileName:filename,
                             type: type,
                             renderType: renderType,
                             sendAsFile: true)
    }
    
    // MARK: Public static helper functions
    
    /// Checks if the given png UIImage and uti combination could be represented as a sticker (render type 2)
    /// - Parameters:
    ///   - image: any png image
    ///   - uti: any uti type
    /// - Returns: true if it can be represented as a sticker and false otherwise
    @objc static func isPNGSticker(image : UIImage, uti : String) -> Bool {
        if UTIConverter.isPNGImageMimeType(UTIConverter.mimeType(fromUTI: uti)) {
            guard let cgImage = image.cgImage else {
                return false
            }
            
            let hasAlpha = ImageURLSenderItemCreator.hasAlpha(image: cgImage)
            let isTransparent = ImageURLSenderItemCreator.hasTransparentPixel(cgImage: cgImage)
            
            return hasAlpha && isTransparent
        }
        return false
    }

    public static func hasAlpha(image : CGImage) -> Bool {
        let alpha: CGImageAlphaInfo = image.alphaInfo
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
    
    public static func hasTransparentPixel(cgImage : CGImage) -> Bool {
        if !(cgImage.alphaInfo == .last || cgImage.alphaInfo == .premultipliedLast || cgImage.alphaInfo == .first || cgImage.alphaInfo == .premultipliedFirst) {
            return false
        }
        
        if cgImage.colorSpace?.model != .rgb {
            // We only deal with rgb
            return false
        }
        
        let bytesPerComponent = cgImage.bitsPerComponent / 8
        if bytesPerComponent > 8 {
            // Might overflow UInt64
            return false
        }
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            fatalError("Couldn't access image data")
        }
        
        let alphaPosition = cgImage.alphaInfo == .last || cgImage.alphaInfo == .premultipliedLast ? 3 : 0
        
        let newData = NSData(bytes: bytes + (alphaPosition * bytesPerComponent), length: bytesPerComponent)
        let alpha : UInt64 = newData.bytes.load(as: UInt64.self)
        
        return alpha == 0
    }
    
    /// Returns the UTI from Data by checking the first byte. Not all UTTypes are covered, check
    /// that all possible UTTypes for your object are covered.
    /// - Parameter data: any Data object
    /// - Returns: A CFString with the UTType of the Data object.
    @objc static func getUTI(for data : Data) -> CFString? {
        var values = [UInt8](repeating:0, count:1)
        data.copyBytes(to: &values, count: 1)
        switch (values[0]) {
            case 0xFF:
                return kUTTypeJPEG
            case 0x89:
                return kUTTypePNG
            case 0x47:
                return kUTTypeGIF
            default:
                break
        }
        return nil
    }
    
    @objc public static func createCorrelationID() -> String {
        return SwiftUtils.pseudoRandomString(length: 32)
    }
    
    // MARK: Public Helper Functions
    func imageMaxSize(_ image: UIImage? = nil) -> CGFloat {
        var maxSize : CGFloat
        
        switch self.userSettingsImageSize {
            case "small":
                maxSize = ImageURLSenderItemCreator.kImageSizeSmall
            case "large":
                maxSize = ImageURLSenderItemCreator.kImageSizeLarge
            case "xlarge":
                maxSize = ImageURLSenderItemCreator.kImageSizeXLarge
            case "original":
                if let image = image {
                    maxSize = max(image.size.width, image.size.height) * image.scale
                } else {
                    maxSize = 0
                }
            default:
                maxSize = ImageURLSenderItemCreator.kImageSizeMedium
        }
        
        if maxSize > ImageURLSenderItemCreator.kImageSizeLarge && AppGroup.getCurrentType() == AppGroupTypeShareExtension {
                maxSize = ImageURLSenderItemCreator.kImageSizeLarge
        }
        
        return maxSize
    }
        
    // MARK: Private Helper Functions
    /// Returns true if the given uti is supported by the file message spec
    /// - Parameter uti: any UTI represented as String
    /// - Returns: true if the given uti is supported by the file message spec false otherwise
    static func isAllowedUTI(uti : String) -> Bool {
        let isJPEG = uti == (kUTTypeJPEG as String)
        let isGIF = uti == (kUTTypeGIF as String)
        let isPNG = uti == (kUTTypePNG as String)
        return isJPEG || isGIF || isPNG
    }
    
    static func getImageSizeForString(size : String) -> CGFloat {
        switch size {
            case "small":
                return ImageURLSenderItemCreator.kImageSizeSmall
            case "large":
                return ImageURLSenderItemCreator.kImageSizeLarge
            case "xlarge":
                return ImageURLSenderItemCreator.kImageSizeXLarge
            case "original":
                return ImageURLSenderItemCreator.kImageSizeOriginal
            default:
                return ImageURLSenderItemCreator.kImageSizeMedium
        }
    }
    
    /// Returns the number of supported image sizes
    /// - Returns:
    @objc static func getImageSizeNo() -> Int {
        guard let imageSizes = imageSizes() else {
            return 0
        }
        return imageSizes.count
    }
    
    ///
    /// - Returns: A list of the descriptions of the available image sizes as String
    @objc static func imageSizes() -> [AnyHashable]? {
        return ["small", "medium", "large", "xlarge", "original"]
    }
    
    /// 
    /// - Returns: A list of the sizes of the available image sizes as Float
    @objc static func imagePixelSizes() -> [AnyHashable]? {
        return [
            NSNumber(value: Float(kImageSizeSmall)),
            NSNumber(value: Float(kImageSizeMedium)),
            NSNumber(value: Float(kImageSizeLarge)),
            NSNumber(value: Float(kImageSizeXLarge)),
            NSNumber(value: Float(kImageSizeOriginal))
        ]
    }
}
