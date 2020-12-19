//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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
import CocoaLumberjackSwift

class ImagePreviewItem: MediaPreviewItem, MediaPreviewItemProtocol {
    
    private var image: Data?
    
    override func requestAsset() {
        let manager = PHImageManager()
        
        guard let originalAsset = self.originalAsset else {
            guard let itemUrl = self.itemUrl else {
                return
            }
            do {
                self.image = try Data(contentsOf: itemUrl)
            } catch {
                DDLogError(error.localizedDescription)
            }
            
            if self.image != nil {
                self.uti = UTIConverter.uti(forFileURL: itemUrl)
                self.semaphore.signal()
                self.initThumbnail()
            }
            return
        }
        
        let asset = originalAsset.originalAsset!
        
        if asset.mediaType == PHAssetMediaType.image {
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true
            manager.requestImageData(for: originalAsset.originalAsset!, options: options, resultHandler: { (data, dataUTI, _, _) in
                let resources = PHAssetResource.assetResources(for: asset)
                var orgFilename = "File"
                if resources.count > 0 {
                    orgFilename = resources.first!.originalFilename
                }
                self.filename = orgFilename
                self.uti = dataUTI

                guard let data = data else {
                    return
                }
                self.image = data
                self.semaphore.signal()
                self.initThumbnail()
            })
        }
    }
    
    private func initThumbnail() {
        guard let data = self.image else {
            return
        }
        let dataImage = UIImage(data: data)
        self.thumbnail = MediaConverter.getThumbnailFor(dataImage)
        self.thumbnailSemaphore.signal()
    }
    
    override func getAccessiblityDescription() -> String? {
        guard let originalAsset = self.originalAsset else {
            let text = String(format: NSLocalizedString("image", comment: ""))
            return text
        }
        let asset = originalAsset.originalAsset!
        
        guard let date = asset.creationDate else {
            return nil
        }
        let datetime = DateFormatter.accessibilityDateTime(date)
        let text = String(format: BundleUtil.localizedString(forKey: "imagedate_date"), datetime)
        return text
    }
    
    func getItem() -> Data? {
        if self.image == nil {
            self.semaphore.wait()
            self.semaphore.signal()
        }
        return self.image
    }
}
