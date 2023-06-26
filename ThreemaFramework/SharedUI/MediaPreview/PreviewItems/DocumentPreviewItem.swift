//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Foundation
import PromiseKit
import QuickLook

class DocumentPreviewItem: MediaPreviewItem {
    
    // MARK: Properties
    
    var largeThumbnail: UIImage?
    
    var smallThumbnail: UIImage? {
        if internalThumbnail == nil {
            let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: itemURL!))
            internalThumbnail = UTIConverter.getDefaultThumbnail(forMimeType: mimeType)
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
        return FileUtility.getFileSizeDescription(for: itemURL)
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
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()!.withTint(Colors.text)!
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
        let type = type ?? BundleUtil.localizedString(forKey: "unknown_file_type")
        let fileSizeDescription = fileSizeDescription ?? BundleUtil.localizedString(forKey: "unknown_file_size")
        let name = originalFilename ?? BundleUtil.localizedString(forKey: "unknown_file_name")
        
        return name + type + BundleUtil.localizedString(forKey: "document") + fileSizeDescription
    }
}

// MARK: - QLPreviewItem

extension DocumentPreviewItem: QLPreviewItem {
    var previewItemURL: URL? {
        itemURL
    }
}
