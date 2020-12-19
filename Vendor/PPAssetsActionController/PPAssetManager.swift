import Photos
import ImageIO
import UIKit

struct PPAssetManager {
   
    func getPHAssets(imagesOnly: Bool, fetchLimit: Int, _ handler: @escaping (PHFetchResult<PHAsset>?) -> ()) {
        guard authorizationStatus() == .authorized else {
            handler(nil)
            return
        }
        
        let result: PHFetchResult<PHAsset>
        let options = self.getFetchOptions(fetchLimit)
        
        if imagesOnly {
            result = PHAsset.fetchAssets(with: .image, options: options)
        } else {
            result = PHAsset.fetchAssets(with: options)
        }
        
        handler(result)
    }
    
    private func getFetchOptions(_ fetchLimit: Int) -> PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = fetchLimit
        fetchOptions.includeAssetSourceTypes = .typeUserLibrary
        fetchOptions.predicate = NSPredicate(format: "(mediaType = %d OR mediaType = %d)", argumentArray:[PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue])
        fetchOptions.wantsIncrementalChangeDetails = false
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        return fetchOptions
    }
    
    private func getFetchOptions(_ offset: Int, _ count: Int) -> PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = offset + count
        fetchOptions.wantsIncrementalChangeDetails = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        return fetchOptions
    }
    
    func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                handler(status)
            }
        }
    }
    
    func authorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
    
    func isUnauthorizedAndCameraAvailable() -> Bool {
        return authorizationStatus() != .authorized && UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
