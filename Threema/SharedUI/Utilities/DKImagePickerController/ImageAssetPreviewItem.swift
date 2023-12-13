//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import PromiseKit

class ImageAssetPreviewItem: ImagePreviewItem {
    private typealias Asset = (filename: String, uti: String, imageData: Data)
    override var originalAsset: Any? {
        get {
            super.originalAsset
        }
        set {
            assert(newValue as? DKAsset != nil)
            super.originalAsset = newValue
        }
    }
    
    private var internalUTI: String?
    private var internalImageData: Data?
    private var internalFilename: String?
    
    override var uti: String? {
        internalUTI
    }
    
    var newUti: Promise<String> {
        if let internalUTI {
            return Promise { $0.fulfill(internalUTI) }
        }

        return internalOriginalAsset.map { value in
            self.internalUTI = value.uti
            return value.uti
        }
    }
    
    override var thumbnail: Promise<UIImage> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<UIImage> in
            self.internalOriginalAsset.then { (value: Asset) -> Promise<UIImage> in
                if let internalThumbnail = self.internalThumbnail {
                    return Promise { $0.fulfill(internalThumbnail) }
                }
                
                guard let newThumbnail = MediaConverter.scaleImageData(value.imageData, toMaxSize: 64.0) else {
                    return Promise { $0.reject(MediaPreviewItem.LoadError.unknown) }
                }
                self.internalThumbnail = newThumbnail
                return Promise { $0.fulfill(newThumbnail) }
            }
        }
    }
    
    override var item: Promise<Data> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<Data> in
            if let image = self.internalImageData {
                return Promise { $0.fulfill(image) }
            }
            
            return self.internalOriginalAsset.map(\.imageData)
        }
    }
    
    private var internalOriginalAsset: Promise<Asset> {
        Promise { seal in
            if let filename, let uti, let image = internalImageData {
                seal.fulfill((filename: filename, uti: uti, imageData: image))
                return
            }
            
            guard let originalAsset = originalAsset as? DKAsset else {
                seal.reject(MediaPreviewItem.LoadError.notAvailable)
                return
            }
            
            guard let originalPHAsset = originalAsset.originalAsset else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }

            guard originalPHAsset.mediaType == PHAssetMediaType.image else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }
            
            let manager = PHImageManager()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            
            manager.requestImageData(
                for: originalPHAsset,
                options: options,
                resultHandler: { data, dataUTI, _, _ in
                    let resources = PHAssetResource.assetResources(for: originalPHAsset)
                    var orgFilename = "File"
                    
                    if let originalFilename = resources.first?.originalFilename {
                        orgFilename = originalFilename
                    }
                    
                    guard let dataUTI else {
                        seal.reject(MediaPreviewItem.LoadError.unknown)
                        return
                    }

                    guard let data else {
                        seal.reject(MediaPreviewItem.LoadError.unknown)
                        return
                    }
                    
                    self.internalFilename = orgFilename
                    self.internalUTI = dataUTI
                    self.internalImageData = data
                    
                    seal.fulfill((filename: orgFilename, uti: dataUTI, imageData: data))
                }
            )
        }
    }
    
    func freeMemory() {
        internalImageData = nil
        internalUTI = nil
        filename = nil
    }
    
    init(originalAsset: DKAsset) {
        super.init()
        self.originalAsset = originalAsset
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
        let text = String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "imagedate_date"), datetime)
        return text
    }
}
