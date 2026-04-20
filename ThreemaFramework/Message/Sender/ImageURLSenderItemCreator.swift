import CocoaLumberjackSwift
import CoreServices
import FileUtility
import Foundation
import PromiseKit
import UIKit

public final class ImageURLSenderItemCreator: NSObject {
    private let fallbackMimeType = "application/octet-stream"
    private var userSettingsImageSize: ImageSenderItemSize

    /// Initialization with the image scale settings chosen by the user
    override public init() {
        guard let settings = UserSettings.shared(),
              let imageSize = ImageSenderItemSize(rawValue: settings.imageSize)
        else {
            self.userSettingsImageSize = .medium
            return
        }
        
        self.userSettingsImageSize = imageSize
    }
    
    /// Initialization with a given scale setting. Should only be used for testing.
    /// - Parameter overrideUserSettingsSize: Can be set to any of the image sizes returned by imageSizes()
    /// - Parameter forceSize: Force the override
    init(with overrideUserSettingsSize: ImageSenderItemSize, forceSize: Bool = false) {
        if let userSettings = UserSettings.shared(),
           let settingsImageSize = ImageSenderItemSize(rawValue: userSettings.imageSize),
           !forceSize,
           settingsImageSize.resolution != 0,
           settingsImageSize.resolution <= overrideUserSettingsSize.resolution {
            
            self.userSettingsImageSize = settingsImageSize
        }
        else {
            self.userSettingsImageSize = overrideUserSettingsSize
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
    public func senderItem(from image: Data, uti: String) -> URLSenderItem? {
        guard let img = UIImage(data: image) else {
            return nil
        }
        
        let maxSize: CGFloat = imageMaxSize(nil)
                
        var imageData: Data?
        var renderType: NSNumber = 1
        var finalUti: String = uti
        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? fallbackMimeType

        if UTIConverter.isGifMimeType(mimeType) {
            if isAnimatedSticker(image: img, uti: uti) {
                renderType = 2
            }
            else {
                renderType = 1
            }
        }
        else if isPNGSticker(image: img, uti: uti) {
            renderType = 2

            guard let convData = MediaConverter.scaleImageData(
                to: image,
                toMaxSize: maxSize,
                useJPEG: false,
                withQuality: imageCompressionQuality()
            ) else {
                return nil
            }
            imageData = convData
        }
        else {
            guard let convJpgData = MediaConverter.scaleImageData(
                to: image,
                toMaxSize: maxSize,
                useJPEG: true,
                withQuality: imageCompressionQuality()
            ) else {
                return nil
            }
            imageData = convJpgData
            finalUti = UTType.jpeg.identifier
        }
        
        let finalMimeType = UTIConverter.mimeType(fromUTI: finalUti) ?? fallbackMimeType
        let filename = FileUtility.shared.getTemporarySendableFileName(base: "image") + "." + (
            UTIConverter.preferredFileExtension(forMimeType: finalMimeType) ?? ""
        )
        
        return URLSenderItem(
            data: imageData ?? image,
            fileName: filename,
            type: finalUti,
            renderType: renderType,
            sendAsFile: true
        )
    }
    
    public func senderItem(url: URL, uti: String) -> URLSenderItem? {
        let maxSize: CGFloat = imageMaxSize()
                
        var imageData: Data?
        var renderType: NSNumber = 1
        var finalUti: String = uti
        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? fallbackMimeType

        if UTIConverter.isGifMimeType(mimeType) {
            do {
                imageData = try Data(contentsOf: url)
                                
                guard let data = imageData,
                      let image = UIImage(data: data) else {
                    return nil
                }
                
                if isAnimatedSticker(image: image, uti: uti) {
                    renderType = 2
                }
                else {
                    renderType = 1
                }
            }
            catch {
                DDLogError("\(error.localizedDescription)")
                return nil
            }
        }
        else {
            guard let scaledImage = MediaConverter.scale(image: url, toMaxSize: maxSize) else {
                return nil
            }
            
            if isPNGSticker(image: scaledImage, uti: uti) {
                renderType = 2
                imageData = MediaConverter.pngRepresentation(for: scaledImage)
            }
            else {
                guard let convJpgData = MediaConverter.jpegRepresentation(
                    for: scaledImage,
                    withQuality: imageCompressionQuality()
                ) else {
                    return nil
                }
                imageData = convJpgData
                finalUti = UTType.jpeg.identifier
            }
        }
        
        let finalMimeType = UTIConverter.mimeType(fromUTI: finalUti) ?? fallbackMimeType
        let filename = FileUtility.shared.getTemporarySendableFileName(base: "image") + "." + (
            UTIConverter.preferredFileExtension(forMimeType: finalMimeType) ?? ""
        )
        
        return URLSenderItem(
            data: imageData,
            fileName: filename,
            type: finalUti,
            renderType: renderType,
            sendAsFile: true
        )
    }
    
    /// Create an URLSenderItem from an image represented by an URL.
    /// The image may be converted to jpeg if it is not of a valid type e.g. HEIC will be converted to jpg. PNG will
    /// never be converted to jpg.
    /// - Parameter url: The URL pointing to a valid image in any format readable by UIImage and convertable by
    /// UIImage.jpegData.
    /// - Returns: An URLSenderItem for the image
    public func senderItem(from url: URL) -> URLSenderItem? {
        guard let scheme = url.scheme else {
            return nil
        }
        if (scheme != "file") || FileUtility.shared.fileExists(at: url) == false {
            return nil
        }
        
        do {
            guard var uti = UTIConverter.uti(forFileURL: url) else {
                return nil
            }
            var data = try Data(contentsOf: url)
            if !isAllowedUTI(uti: uti) {
                guard let image = UIImage(data: data) else {
                    return nil
                }
                guard let imageData = MediaConverter.jpegRepresentation(
                    for: image,
                    withQuality: imageCompressionQuality()
                ) else {
                    return nil
                }
                data = imageData
                uti = UTType.jpeg.identifier
                
                guard let item = senderItem(from: data, uti: uti) else {
                    DDLogError("Could not create item")
                    return nil
                }
                return item
            }
            else {
                guard let item = senderItem(url: url, uti: uti) else {
                    DDLogError("Could not create item")
                    return nil
                }
                return item
            }
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Public static helper functions
    
    /// Checks if the given png UIImage and uti combination could be represented as a sticker (render type 2)
    /// - Parameters:
    ///   - image: any png image
    ///   - uti: any uti type
    /// - Returns: True if it can be represented as a sticker and false otherwise (If in ShareExtension, returns always
    /// false due to an issue with screenshots from iOS 26.0)
    func isPNGSticker(image: UIImage, uti: String) -> Bool {
        guard AppGroup.getCurrentType() != AppGroupTypeShareExtension else {
            return false
        }
        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? fallbackMimeType
        if UTIConverter.isPNGImageMimeType(mimeType) {
            guard let cgImage = image.cgImage else {
                return false
            }
            
            let hasAlpha = hasAlpha(image: cgImage)
            let isTransparent = hasTransparentPixel(cgImage: cgImage)
            
            return hasAlpha && isTransparent
        }
        return false
    }

    func isAnimatedSticker(image: UIImage, uti: String) -> Bool {
        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? fallbackMimeType
        if UTIConverter.isGifMimeType(mimeType) {
            guard let cgImage = image.cgImage else {
                return false
            }
            
            let hasAlpha = hasAlpha(image: cgImage)
            let isTransparent = hasTransparentPixel(cgImage: cgImage)
            
            return hasAlpha && isTransparent
        }
        return false
    }
    
    public func hasAlpha(image: CGImage) -> Bool {
        let alpha: CGImageAlphaInfo = image.alphaInfo
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
    
    public func hasTransparentPixel(cgImage: CGImage) -> Bool {
        if !(
            cgImage.alphaInfo == .last || cgImage.alphaInfo == .premultipliedLast || cgImage
                .alphaInfo == .first || cgImage.alphaInfo == .premultipliedFirst
        ) {
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
        let alpha: UInt64 = newData.bytes.load(as: UInt64.self)
        
        return alpha == 0
    }
    
    /// Returns the UTI from Data by checking the first byte. Not all UTTypes are covered, check
    /// that all possible UTTypes for your object are covered.
    /// - Parameter data: any Data object
    /// - Returns: A CFString with the UTType of the Data object.
    public func getUTI(for data: Data) -> NSString? {
        var values = [UInt8](repeating: 0, count: 1)
        data.copyBytes(to: &values, count: 1)
        switch values[0] {
        case 0xFF:
            return UTType.jpeg.identifier as NSString
        case 0x89:
            return UTType.png.identifier as NSString
        case 0x47:
            return UTType.gif.identifier as NSString
        default:
            break
        }
        return nil
    }
    
    public func createCorrelationID() -> String {
        SwiftUtils.pseudoRandomString(length: 32)
    }
    
    // MARK: - Public Helper Functions

    func imageMaxSize(_ image: UIImage? = nil) -> CGFloat {
        var maxSize: CGFloat =
            switch userSettingsImageSize {
            case .small, .medium, .large, .extraLarge:
                userSettingsImageSize.resolution
            case .original:
                if let image {
                    max(image.size.width, image.size.height) * image.scale
                }
                else {
                    0
                }
            }
        
        if AppGroup.getCurrentType() == AppGroupTypeShareExtension,
           maxSize > ImageSenderItemSize.large.resolution {
            maxSize = ImageSenderItemSize.large.resolution
        }
        
        return maxSize
    }
    
    /// Returns the maximum size of the longest edge of media thumbnails to be sent
    /// The size should be in between 128px and 512px
    @objc public func imageThumbnailMaxSize(_ image: UIImage?) -> CGFloat {
        let thumbnailSize = min(imageMaxSize(image) / 3, 512)
        return max(128, thumbnailSize)
    }
    
    @objc public func stickerThumbnailMaxSize(_ image: UIImage?) -> CGFloat {
        let maxStickerSize: CGFloat = 400
        if let image,
           image.size.width < maxStickerSize,
           image.size.height < maxStickerSize {
            return max(image.size.width, image.size.height)
        }

        let thumbnailSize = min(imageMaxSize(image) / 2, 1024)
        return max(400, thumbnailSize)
    }
    
    func imageCompressionQuality() -> Double {
        if userSettingsImageSize == .original {
            return kJPEGCompressionQualityHigh
        }
        return kJPEGCompressionQualityLow
    }
    
    func imageCompressionQuality() -> NSNumber {
        NSNumber(value: imageCompressionQuality())
    }
        
    // MARK: - Private Helper Functions
    
    /// Returns true if the given uti is supported by the file message spec
    /// - Parameter uti: any UTI represented as String
    /// - Returns: true if the given uti is supported by the file message spec false otherwise
    func isAllowedUTI(uti: String) -> Bool {
        let isJPEG = uti == UTType.jpeg.identifier
        let isGIF = uti == UTType.gif.identifier
        let isPNG = uti == UTType.png.identifier
        return isJPEG || isGIF || isPNG
    }
    
    ///
    /// - Returns: A list of the descriptions of the available image sizes as String
    public static var imageSizes: [ImageSenderItemSize] {
        [
            .small,
            .medium,
            .large,
            .extraLarge,
            .original,
        ]
    }
}
