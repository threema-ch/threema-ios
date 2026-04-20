import CocoaLumberjackSwift
import FileUtility
import Foundation
import PromiseKit
import QuickLook
import ThreemaMacros

class DocumentPreviewItem: MediaPreviewItem {
    
    // MARK: Properties
    
    var largeThumbnail: UIImage?
    
    var smallThumbnail: UIImage? {
        if internalThumbnail == nil {
            if let itemURL {
                let utiIdentifier = UTIConverter.uti(forFileURL: itemURL) ?? UTType.data.identifier
                let mimeType = UTIConverter.mimeType(fromUTI: utiIdentifier) ?? "application/octet-stream"
                internalThumbnail = UTIConverter.getDefaultThumbnail(forMimeType: mimeType)
            }
            else {
                internalThumbnail = UTIConverter.getDefaultThumbnail(forMimeType: "unknown")
            }
        }
        
        return internalThumbnail
    }
    
    var originalFilename: String? {
        itemURL?.lastPathComponent
    }
    
    var fileSizeDescription: String? {
        guard let itemURL else {
            return nil
        }
        return FileUtility.shared.getFileSizeDescription(for: itemURL)
    }
    
    var type: String? {
        guard let type = itemURL?.pathExtension else {
            return nil
        }
        let uppercaseType = type.uppercased()
        return uppercaseType
    }
    
    var previewable: Bool {
        QLPreviewController.canPreview(self)
    }
    
    // MARK: Overridden properties
    
    override var thumbnail: Promise<UIImage> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<UIImage> in
            Promise { seal in
                let size = 30
                let frameSize = 50
                guard let image = self.smallThumbnail else {
                    seal.reject(MediaPreviewItem.LoadError.unknown)
                    return
                }
                
                UIGraphicsBeginImageContextWithOptions(CGSize(width: 50, height: 50), false, 0.0)
                let inset = (frameSize - size) / 2
                image.draw(in: CGRect(x: inset, y: inset, width: size, height: size))
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()?.withTintColor(.label)
                UIGraphicsEndImageContext()
                
                seal.resolve(finalImage, nil)
            }
        }
    }
    
    func generateLargeThumbnail(with size: CGSize) -> Promise<UIImage> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<UIImage> in
            if let largeThumbnail = self.largeThumbnail {
                return .value(largeThumbnail)
            }
            return Promise { seal in
                let gen = QLThumbnailGenerator.shared
                let request = QLThumbnailGenerator.Request(
                    fileAt: self.itemURL!,
                    size: size,
                    scale: UIScreen.main.scale,
                    representationTypes: .thumbnail
                )
                
                gen.generateBestRepresentation(for: request) { thumbnail, error in
                    
                    guard let thumbnail else {
                        seal.reject(error ?? MediaPreviewItem.LoadError.unknown)
                        return
                    }
                    
                    self.largeThumbnail = thumbnail.uiImage
                    seal.fulfill(thumbnail.uiImage)
                }
            }
        }
    }
    
    // MARK: Overridden functions
    
    override func freeMemory() {
        super.freeMemory()
        largeThumbnail = nil
    }
    
    override func getAccessibilityDescription() -> String? {
        let type = type ?? #localize("unknown_file_type")
        let fileSizeDescription = fileSizeDescription ?? #localize("unknown_file_size")
        let name = originalFilename ?? #localize("unknown_file_name")
        
        return name + type + #localize("document") + fileSizeDescription
    }
}

// MARK: - QLPreviewItem

extension DocumentPreviewItem: QLPreviewItem {
    var previewItemURL: URL? {
        itemURL
    }
}
