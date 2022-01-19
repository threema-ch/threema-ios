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

import Foundation
import CocoaLumberjackSwift

class VideoAssetPreviewItem : VideoPreviewItem {
    private var assetItem : AVAsset?
    
    override var originalAsset: Any?  {
        get {
            return super.originalAsset
        }
        set {
            assert(newValue as? DKAsset != nil)
            super.originalAsset = newValue
        }
    }
    
    init(originalAsset: DKAsset) {
        super.init()
        self.originalAsset = originalAsset
    }
    
    override func requestAsset() {
        let manager = PHImageManager()
        
        guard let originalAsset = self.originalAsset as? DKAsset else {
            super.requestAsset()
            return
        }
        
        let asset = originalAsset.originalAsset!
        
        if asset.mediaType == PHAssetMediaType.video {
            let options = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            manager.requestAVAsset(forVideo: asset, options: options, resultHandler: {
                (avasset, _, _) in
                self.thumbnail = MediaConverter.getThumbnailForVideo(avasset)
                self.thumbnailSemaphore.signal()
                if let avassetURL = avasset as? AVURLAsset {
                    self.itemUrl = avassetURL.url
                } else {
                    self.assetItem = avasset
                }
                self.semaphore.signal()
            })
        }
    }
    
    override func getAccessiblityDescription() -> String? {
        guard let originalAsset = self.originalAsset as? DKAsset else {
            return super.getAccessiblityDescription()
        }
        
        let asset = originalAsset.originalAsset!
        guard let date = asset.creationDate else {
            return nil
        }
        let datetime = DateFormatter.accessibilityDateTime(date)
        let text = String(format: NSLocalizedString("video_date", comment: ""),"\(String(describing: datetime))")
        return text
    }
    
    override func convertVideo() {
        if self.itemUrl != nil {
            super.convertVideo()
        } else {
            guard let asset = assetItem else {
                let message = "asset was unexpectedly nil"
                DDLogError(message)
                fatalError(message)
            }
            super.convertAsset(asset: asset)
        }
    }
    
    func getItem() -> AVAsset? {
        if self.itemUrl == nil {
            if let avasset = self.assetItem {
                return avasset
            }
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
