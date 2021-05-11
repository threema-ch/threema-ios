//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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
import QuickLook
import PromiseKit
import CocoaLumberjackSwift

enum PreviewItemError : Error {
    case unknown
    case osNotSupported
}

class DocumentPreviewItem : MediaPreviewItem {
    
    var largeThumbnail : UIImage?
    
    func getFilename() -> String? {
        return self.itemUrl?.lastPathComponent
    }
    
    override func getThumbnail() -> UIImage? {
        return getSmallThumbnail()
    }
    
    override func getAccessiblityDescription() -> String? {
        let type = self.getType() ?? BundleUtil.localizedString(forKey: "unknown_file_type")
        let size = self.getSize() ?? BundleUtil.localizedString(forKey: "unknown_file_size")
        let name = self.getFilename() ?? BundleUtil.localizedString(forKey: "unknown_file_name")
        
        return name + type + BundleUtil.localizedString(forKey: "document") + size
    }
    
    override func getThumbnail(onCompletion: (UIImage) -> Void) {
        let size = 30
        let frameSize = 50
        let image = self.getSmallThumbnail()
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 50, height: 50), false, 0.0);
        let inset = (frameSize - size)/2
        image.draw(in: CGRect(x: inset, y: inset, width: size, height: size))
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!.withTint(Colors.fontNormal()!)!
        UIGraphicsEndImageContext();
                
        onCompletion(finalImage)
    }
    
    func getSize() -> String? {
        do {
            let resources = try self.itemUrl!.resourceValues(forKeys:[.fileSizeKey])
            let fileSize = Int64(resources.fileSize!)
            let size = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            return size
        } catch {
            DDLogError("Error: \(error)")
        }
        return nil
    }
    
    func getType() -> String? {
        guard let type = self.itemUrl?.pathExtension else {
            return nil
        }
        let uppercaseType = type.uppercased()
        return uppercaseType
    }
    
    func generateLargeThumbnail(with size : CGSize) -> Promise<UIImage?> {
        if self.largeThumbnail != nil {
            return .value(self.largeThumbnail!)
        }
        return Promise { seal in
            if #available(iOSApplicationExtension 13.0, *) {
                let gen = QLThumbnailGenerator.shared
                let request = QLThumbnailGenerator.Request(fileAt: self.itemUrl!,
                                                           size: size,
                                                           scale: UIScreen.main.scale,
                                                           representationTypes: .thumbnail)
                
                gen.generateBestRepresentation(for: request) { (thumbnail, error) in
                    if thumbnail == nil || error != nil {
                        seal.reject(error ?? PreviewItemError.unknown)
                    } else {
                        self.largeThumbnail =  thumbnail!.uiImage
                        seal.fulfill(self.largeThumbnail)
                    }
                }
            } else {
                // Creating a thumbnail for an item is only supported in iOS 13 and newer
                // On older system we therefore do not have a thumbnail.
                // Typically an icon for the file is shown instead.
                seal.reject(PreviewItemError.osNotSupported)
            }
        }
    }
    
    func getSmallThumbnail() -> UIImage {
        if self.thumbnail == nil {
            let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: self.itemUrl!))
            self.thumbnail =  UTIConverter.getDefaultThumbnail(forMimeType: mimeType)
        }
        
        return self.thumbnail!
    }
    
    func isPreviewable() -> Bool {
        QLPreviewController.canPreview(self)
    }
    
    override func freeMemory() {
        super.freeMemory()
        self.largeThumbnail = nil
    }
    
}

extension DocumentPreviewItem : QLPreviewItem {
    var previewItemURL: URL? {
        return self.itemUrl
    }
}
