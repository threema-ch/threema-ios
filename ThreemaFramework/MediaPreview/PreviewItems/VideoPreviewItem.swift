//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

open class VideoPreviewItem: MediaPreviewItem, MediaPreviewItemProtocol {
    var video: Data?
    var isConverting = false
    var isConverted = false
    var exportSession : SDAVAssetExportSession?
    
    var transcodeSema = DispatchSemaphore(value: 0)
    var transcodedItem : URL?
    
    open override func requestAsset() {
        guard let itemUrl = self.itemUrl else {
            return
        }
        let asset = AVAsset(url: itemUrl)
        self.thumbnail = MediaConverter.getThumbnailForVideo(asset)
        self.thumbnailSemaphore.signal()
        self.semaphore.signal()
    }
    
    open override func getAccessiblityDescription() -> String? {
        let text = BundleUtil.localizedString(forKey:"video")
        return text
    }
    
    open func convertVideo() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.isConverted {
                if !self.isConverting {
                    self.isConverting = true
                    
                    guard let url = self.getItem() else {
                        self.isConverting = false
                        return
                    }
                    
                    let asset = AVURLAsset(url: url)
                    self.convertAsset(asset: asset)
                }
            }
        }
    }
    
    public func convertAsset(asset : AVAsset) {
        let outputURL = MediaConverter.getAssetOutputURL()
        self.exportSession = MediaConverter.getAVAssetExportSession(from: asset, outputURL: outputURL)
        autoreleasepool {
            MediaConverter.convertVideoAsset(asset, with: self.exportSession) { (url) in
                self.transcodedItem = url
                self.isConverted = true
                self.transcodeSema.signal()
                self.exportSession = nil
            } onError: { (error : Error?) -> Void in
                DDLogError("Could not convert video \(error.debugDescription)")
                self.exportSession = nil
            }
        }
        
        self.transcodeSema.wait()
        self.transcodeSema.signal()
    }
    
    public func getItem() -> URL? {
        self.convertVideo()
        return self.itemUrl
    }
    
    open func getTranscodedItem() -> URL? {
        self.convertVideo()
        self.transcodeSema.wait()
        self.transcodeSema.signal()
        
        return self.transcodedItem
    }
    
    open func getOriginalItem() -> URL? {
        return self.itemUrl
    }
    
    override func freeMemory() {
        video = nil
    }
}

