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

class VideoPreviewItem: MediaPreviewItem, MediaPreviewItemProtocol {
    
    var video: Data?
    var isConverting = false
    var isConverted = false
    
    var transcodeSema = DispatchSemaphore(value: 0)
    
    override func requestAsset() {
        let manager = PHImageManager()
        
        guard let originalAsset = self.originalAsset else {
            guard let itemUrl = self.itemUrl else {
                return
            }
            let asset = AVAsset(url: itemUrl)
            self.thumbnail = MediaConverter.getThumbnailForVideo(asset)
            self.thumbnailSemaphore.signal()
            self.semaphore.signal()
            
            return
        }
        
        let asset = originalAsset.originalAsset!
        
        if asset.mediaType == PHAssetMediaType.video {
            let options = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            manager.requestAVAsset(forVideo: asset, options: options, resultHandler: {
                (avasset, _, _) in
                self.thumbnail = MediaConverter.getThumbnailForVideo(avasset)
                self.thumbnailSemaphore.signal()
                if let avassetURL = avasset as? AVURLAsset {
                    self.itemUrl = avassetURL.url
                    self.semaphore.signal()
                }
            })
        }
    }
    
    override func getAccessiblityDescription() -> String? {
        guard let originalAsset = self.originalAsset else {
            let text = String(format: NSLocalizedString("video", comment: ""))
            return text
        }
        
        let asset = originalAsset.originalAsset!
        guard let date = asset.creationDate else {
            return nil
        }
        let datetime = DateFormatter.accessibilityDateTime(date)
        let text = String(format: NSLocalizedString("video_date", comment: ""),"\(String(describing: datetime))")
        return text
    }
    
    func convertVideo() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.isConverted {
                if !self.isConverting {
                    self.isConverting = true
                    
                    MediaConverter.convertVideoAsset(self.getItem()!, onCompletion: {
                        (url) in
                        self.video = try? Data(contentsOf: url!)
                        self.itemUrl = url
                        self.isConverted = true
                        self.transcodeSema.signal()
                    }, onError: {
                        (error) in
                        DDLogError("Could not convert video \(error.debugDescription)")
                    })
                    
                }
                self.transcodeSema.wait()
                self.transcodeSema.signal()
            }
        }
    }
    
    func getItem() -> URL? {
        self.convertVideo()
        return self.itemUrl
    }
    
    func getTranscodedItem() -> URL? {
        self.convertVideo()
        self.transcodeSema.wait()
        self.transcodeSema.signal()

        return self.itemUrl
    }
    
    func getItem() -> Data? {
        self.convertVideo()
        return self.video
    }
    
    func getItem() -> AVAsset? {
        if self.itemUrl == nil {
            self.semaphore.wait()
            self.semaphore.signal()
        }
        guard let url : URL = self.getItem() else {
            return nil
        }
        let asset = AVAsset(url: url)
        return asset
    }
}

