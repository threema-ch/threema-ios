import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaMacros

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
                    
                    guard let avasset else {
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
        let text = String.localizedStringWithFormat(
            #localize("video_date"),
            datetime
        )
        return text
    }
}
