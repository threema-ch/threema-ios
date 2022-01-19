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

@objc open class MediaPreviewURLDataProcessor : NSObject {
    
    public var cancelAction : (() -> Void)?
    public var memoryConstrained = false
    public var sendAsFile = false
    
    open func loadItems(dataArray : [Any]) -> (items: [MediaPreviewItem], errors: [PhotosPickerError]) {
        var mediaData = [MediaPreviewItem]()
        var errorList = [PhotosPickerError]()
        for index in 0..<dataArray.count {
            guard let item = self.loadItem(item: dataArray[index]) else {
                errorList.append(PhotosPickerError.unknown)
                continue
            }
            mediaData.append(item)
        }
        
        return (mediaData, errorList)
    }
    
    open func loadItem(item : Any) -> MediaPreviewItem? {
        switch item {
            case is MediaPreviewItem:
                return item as? MediaPreviewItem
            case is URL, is NSURL:
                let url = item as! URL
                guard let item = addDataItemFrom(url: url) else {
                    return nil
                }
                item.memoryConstrained = memoryConstrained
                return item
            case is PhotosPickerError:
                return nil
            default:
                return nil
        }
    }
    
    open func addDataItemFrom(url: URL) -> MediaPreviewItem? {
        let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
        if UTIConverter.isImageMimeType(mimeType) {
            let item = ImagePreviewItem(itemUrl: url)
            return item
        } else if UTIConverter.isMovieMimeType(mimeType) || UTIConverter.isVideoMimeType(mimeType) {
            let item = VideoPreviewItem(itemUrl: url)
            return item
        } else {
            let item = DocumentPreviewItem(itemUrl: url)
            return item
        }
    }
    
    open func processItemForSending(item : MediaPreviewItem) -> Any? {
        if item is ImagePreviewItem {
            guard let assetUrl = item.itemUrl else {
                return nil
            }
            return assetUrl
        }
        
        if item is VideoPreviewItem {
            guard let videoItem = item as? VideoPreviewItem else {
                return nil
            }
            return sendAsFile ? videoItem.getOriginalItem() : videoItem.getTranscodedItem()
        }
        
        if item is DocumentPreviewItem {
            guard let documentItem = item as? DocumentPreviewItem else {
                return nil
            }
            guard let assetUrl : URL = documentItem.itemUrl else {
                return nil
            }
            return assetUrl
        }
        
        let err = "Unknown Media Type processed"
        DDLogError(err)
        fatalError(err)
    }
    
    open func returnAction(mediaData : [MediaPreviewItem]) {
        let err = "Not implemented"
        DDLogError(err)
        fatalError(err)
    }
    
    open func requestAssets(queue : DispatchQueue, mediaData : [MediaPreviewItem]) {
        queue.async {
            for index in 0..<mediaData.count {
                mediaData[index].requestAsset()
            }
        }
    }
    
    open func executeCancelAction() {
        if cancelAction != nil {
            cancelAction!()
        }
    }
    
}
