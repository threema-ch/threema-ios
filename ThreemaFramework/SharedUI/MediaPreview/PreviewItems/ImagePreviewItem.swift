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
import Photos
import PromiseKit

open class ImagePreviewItem: MediaPreviewItem {
    public typealias PreviewType = Data
    
    private var internalImage: Data?
    
    private var internalOriginalAsset: Promise<PreviewType> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<PreviewType> in
            if let internalImage = self.internalImage {
                return Promise { $0.fulfill(internalImage) }
            }
            
            guard let itemURL = self.itemURL else {
                return Promise { $0.reject(MediaPreviewItem.LoadError.unknown) }
            }
            
            guard self.estimatedFileSize < kShareExtensionMaxImagePreviewSize || !self.memoryConstrained else {
                return Promise { $0.reject(MediaPreviewItem.LoadError.memoryConstrained) }
            }
            
            return Promise { seal in
                guard let imageData = try? Data(contentsOf: itemURL) else {
                    seal.reject(MediaPreviewItem.LoadError.unknown)
                    return
                }
                self.internalImage = imageData
                seal.fulfill(imageData)
            }
        }
    }
    
    override open var thumbnail: Promise<UIImage> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<UIImage> in
            if let internalThumbnail = self.internalThumbnail {
                return Promise { $0.fulfill(internalThumbnail) }
            }
            
            guard let itemURL = self.itemURL else {
                return Promise { $0.reject(MediaPreviewItem.LoadError.notAvailable) }
            }
            
            guard let newThumbnail = MediaConverter.scale(image: itemURL, toMaxSize: 64.0) else {
                return Promise { $0.reject(MediaPreviewItem.LoadError.unknown) }
            }
            self.internalThumbnail = newThumbnail
            return Promise { $0.fulfill(newThumbnail) }
        }
    }
    
    open var item: Promise<PreviewType> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<PreviewType> in
            if let image = self.internalImage {
                return Promise { $0.fulfill(image) }
            }
            
            return self.internalOriginalAsset
        }
    }
    
    var previewImage: Promise<UIImage> {
        Promise { seal in
            guard estimatedFileSize < kShareExtensionMaxImagePreviewSize else {
                seal.reject(MediaPreviewItem.LoadError.memoryConstrained)
                return
            }
            
            guard let itemURL else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }
            
            let size = MediaConverter.fullscreenPreviewSizeForCurrentDevice()
            guard let image = MediaConverter.scale(image: itemURL, toMaxSize: CGFloat(size)) else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }
            seal.fulfill(image)
        }
    }
    
    override open func getAccessibilityDescription() -> String? {
        let text = BundleUtil.localizedString(forKey: "image")
        return text
    }
    
    override func freeMemory() {
        super.freeMemory()
        internalImage = nil
        internalThumbnail = nil
    }
}
