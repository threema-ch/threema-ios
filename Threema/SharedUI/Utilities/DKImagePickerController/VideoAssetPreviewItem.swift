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
import Foundation

class VideoAssetPreviewItem: VideoPreviewItem {
    private var assetItem: AVAsset?
    
    override var originalAsset: Any? {
        get {
            super.originalAsset
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
    
    override open var internalOriginalAsset: Promise<AVAsset> {
        Promise { seal in
            let manager = PHImageManager()
            
            guard let originalAsset = originalAsset as? DKAsset else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }
            
            let asset = originalAsset.originalAsset!
            
            if asset.mediaType == PHAssetMediaType.video {
                let options = PHVideoRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .automatic
                manager.requestAVAsset(forVideo: asset, options: options, resultHandler: {
                    avasset, _, _ in
                    
                    guard let avasset = avasset else {
                        seal.reject(MediaPreviewItem.LoadError.unknown)
                        return
                    }

                    self.assetItem = avasset
                    seal.fulfill(avasset)
                })
            }
        }
    }
    
    override func getOriginalItem() -> URL? {
        guard let urlAssetItem = assetItem as? AVURLAsset else {
            return nil
        }
        return urlAssetItem.url
    }
    
    override func getAccessibilityDescription() -> String? {
        guard let originalAsset = originalAsset as? DKAsset else {
            return super.getAccessibilityDescription()
        }
        
        let asset = originalAsset.originalAsset!
        guard let date = asset.creationDate else {
            return nil
        }
        let datetime = DateFormatter.accessibilityDateTime(date)
        let text = String(format: BundleUtil.localizedString(forKey: "video_date"), "\(String(describing: datetime))")
        return text
    }
}
