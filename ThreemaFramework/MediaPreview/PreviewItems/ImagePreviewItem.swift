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
import CocoaLumberjackSwift
import Photos

open class ImagePreviewItem: MediaPreviewItem, MediaPreviewItemProtocol {
    
    open var image: Data?
    
    override open func requestAsset() {
        if self.image != nil {
            self.uti = UTIConverter.uti(forFileURL: itemUrl)
            semaphore.signal()
            return
        }
        guard let itemUrl = self.itemUrl else {
            let err = "Illegal item"
            DDLogError(err)
            fatalError(err)
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
    }
    
    open func initThumbnail() {
        guard let data = self.image else {
            return
        }
        let size = MediaConverter.thumbnailSizeForCurrentDevice()
        self.thumbnail = MediaConverter.scaleImageData(data, toMaxSize: CGFloat(size))
        self.thumbnailSemaphore.signal()
    }
    
    open override func getAccessiblityDescription() -> String? {
        let text = BundleUtil.localizedString(forKey: "image")
        return text
    }
    
    public func getItem() -> Data? {
        if self.image == nil {
            self.requestAsset()
            self.semaphore.wait()
            self.semaphore.signal()
        }
        return self.image
    }
    
    override func freeMemory() {
        super.freeMemory()
        image = nil
    }
}
