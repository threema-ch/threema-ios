//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

import CocoaLumberjackSwift
import CoreServices
import Foundation
import PromiseKit

public class ImageURLSenderItemCreator: NSObject {
    
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
    @objc public func senderItem(from image: Data, uti: String) -> URLSenderItem? {
        guard let img = UIImage(data: image) else {
            return nil
        }
        
        let maxSize: CGFloat = imageMaxSize(nil)
                
        var imageData: Data?
        var renderType: NSNumber = 1
        var finalUti: String = uti
        
        if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: uti)) {
            
            if ImageURLSenderItemCreator.isAnimatedSticker(image: img, uti: uti) {
                renderType = 2
            }
            else {
                renderType = 1
            }
        }
        else if ImageURLSenderItemCreator.isPNGSticker(image: img, uti: uti) {
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
            finalUti = kUTTypeJPEG as String
        }
        
        let mimeType = UTIConverter.mimeType(fromUTI: finalUti)
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + "." + (
            UTIConverter.preferredFileExtension(forMimeType: mimeType) ?? ""
        )
        
        return URLSenderItem(
            data: imageData ?? image,
            fileName: filename,
            type: finalUti,
            renderType: renderType,
            sendAsFile: true
        )
    }
    
    @objc public func senderItem(url: URL, uti: String) -> URLSenderItem? {
        let maxSize: CGFloat = imageMaxSize()
                
        var imageData: Data?
        var renderType: NSNumber = 1
        var finalUti: String = uti
        
        if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: uti)) {

            do {
                imageData = try Data(contentsOf: url)
                                
                guard let data = imageData,
                      let image = UIImage(data: data) else {
                    return nil
                }
                
                if ImageURLSenderItemCreator.isAnimatedSticker(image: image, uti: uti) {
                    renderType = 2
                }
                else {
                    renderType = 1
                }
            }
            catch {
                DDLogError(error.localizedDescription)
                return nil
            }
        }
        else {
            guard let scaledImage = MediaConverter.scale(image: url, toMaxSize: maxSize) else {
                return nil
            }
            
            if ImageURLSenderItemCreator.isPNGSticker(image: scaledImage, uti: uti) {
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
                finalUti = kUTTypeJPEG as String
            }
        }
        
        let mimeType = UTIConverter.mimeType(fromUTI: finalUti)
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + "." + (
            UTIConverter.preferredFileExtension(forMimeType: mimeType) ?? ""
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
    /// The image may be converted to jpeg if it is not of a valid type e.g. HEIC will be converted to jpg. PNG will never be converted to jpg.
    /// - Parameter url: The URL pointing to a valid image in any format readable by UIImage and convertable by UIImage.jpegData.
    /// - Returns: An URLSenderItem for the image
    @objc public func senderItem(from url: URL) -> URLSenderItem? {
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
                guard let imageData = MediaConverter.jpegRepresentation(
                    for: image,
                    withQuality: imageCompressionQuality()
                ) else {
                    return nil
                }
                data = imageData
                uti = kUTTypeJPEG as String
                
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
            DDLogError(error.localizedDescription)
        }
        return nil
    }
    
    /// Create an URLSenderItem from an image represented by an UIImage object
    /// The image will always be converted to jpg
    /// - Parameter image: An image
    /// - Returns: An URLSenderItem for the image
    @available(
        *,
        deprecated,
        message: "Is only available for to support legacy Objective-C code. Please use any of the other functions"
    )
    @objc func senderItem(fromImage image: UIImage) -> URLSenderItem? {
        guard let image = MediaConverter.scale(image, toMaxSize: imageMaxSize(image)) else {
            return nil
        }
        
        let data = MediaConverter.jpegRepresentation(for: image, withQuality: imageCompressionQuality())!
        let type = kUTTypeJPEG as String
        let renderType: NSNumber = 1
        
        let ext = UTIConverter.preferredFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: type))!
        let filename = FileUtility.getTemporarySendableFileName(base: "image") + ext
        
        return URLSenderItem(
            data: data,
            fileName: filename,
            type: type,
            renderType: renderType,
            sendAsFile: true
        )
    }
    
    // MARK: - Public static helper functions
    
    /// Checks if the given png UIImage and uti combination could be represented as a sticker (render type 2)
    /// - Parameters:
    ///   - image: any png image
    ///   - uti: any uti type
    /// - Returns: true if it can be represented as a sticker and false otherwise
    @objc static func isPNGSticker(image: UIImage, uti: String) -> Bool {
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

    @objc static func isAnimatedSticker(image: UIImage, uti: String) -> Bool {
        if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: uti)) {
            guard let cgImage = image.cgImage else {
                return false
            }
            
            let hasAlpha = ImageURLSenderItemCreator.hasAlpha(image: cgImage)
            let isTransparent = ImageURLSenderItemCreator.hasTransparentPixel(cgImage: cgImage)
            
            return hasAlpha && isTransparent
        }
        return false
    }
    
    public static func hasAlpha(image: CGImage) -> Bool {
        let alpha: CGImageAlphaInfo = image.alphaInfo
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
    
    public static func hasTransparentPixel(cgImage: CGImage) -> Bool {
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
    @objc public static func getUTI(for data: Data) -> CFString? {
        var values = [UInt8](repeating: 0, count: 1)
        data.copyBytes(to: &values, count: 1)
        switch values[0] {
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
        SwiftUtils.pseudoRandomString(length: 32)
    }
    
    // MARK: - Public Helper Functions

    func imageMaxSize(_ image: UIImage? = nil) -> CGFloat {
        var maxSize: CGFloat
        
        switch userSettingsImageSize {
        case .small, .medium, .large, .extraLarge:
            maxSize = userSettingsImageSize.resolution
        case .original:
            if let image = image {
                maxSize = max(image.size.width, image.size.height) * image.scale
            }
            else {
                maxSize = 0
            }
        }
        
        if AppGroup.getCurrentType() == AppGroupTypeShareExtension,
           maxSize > ImageSenderItemSize.large.resolution {
            maxSize = ImageSenderItemSize.large.resolution
        }
        
        return maxSize
    }
    
    /// Returns the maximum size of the longest edge of media thumbnails to be sent
    /// The size should be inbetween 128px and 512px
    @objc public func imageThumbnailMaxSize(_ image: UIImage?) -> CGFloat {
        let thumbnailSize = min(imageMaxSize(image) / 3, 512)
        return max(128, thumbnailSize)
    }
    
    @objc public func stickerThumbnailMaxSize(_ image: UIImage?) -> CGFloat {
        let maxStickerSize: CGFloat = 400
        if let image = image,
           image.size.width < maxStickerSize,
           image.size.height < maxStickerSize {
            return max(image.size.width, image.size.height)
        }

        let thumbnailSize = min(imageMaxSize(image) / 2, 1024)
        return max(400, thumbnailSize)
    }
    
    func imageCompressionQuality() -> Double {
        if userSettingsImageSize.rawValue == "original" {
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
    static func isAllowedUTI(uti: String) -> Bool {
        let isJPEG = uti == (kUTTypeJPEG as String)
        let isGIF = uti == (kUTTypeGIF as String)
        let isPNG = uti == (kUTTypePNG as String)
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
