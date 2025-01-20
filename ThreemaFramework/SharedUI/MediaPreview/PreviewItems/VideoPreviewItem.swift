//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaMacros

open class VideoPreviewItem: MediaPreviewItem, MediaPreviewItemProtocol {
    public typealias PreviewType = URL
    
    var exportSession: AVAssetExportSession?
    var isConverted = false
    
    // MARK: Private Properties
    
    private var video: Data?
    private var isConverting = false
    
    private var transcodeSema = DispatchSemaphore(value: 0)
    private var transcodedItem: URL?
    
    open var internalOriginalAsset: Promise<AVAsset> {
        Promise { seal in
            guard let itemURL else {
                seal.reject(MediaPreviewItem.LoadError.unknown)
                return
            }
            
            seal.fulfill(AVAsset(url: itemURL))
        }
    }
    
    override open var thumbnail: Promise<UIImage> {
        internalOriginalAsset.then { asset in
            self.getThumbnail(for: asset)
        }
    }
    
    private func getThumbnail(for avasset: AVAsset) -> Promise<UIImage> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<UIImage> in
            Promise { seal in
                if let internalThumbnail = self.internalThumbnail {
                    seal.fulfill(internalThumbnail)
                }
                guard let image = MediaConverter.getThumbnailForVideo(avasset) else {
                    seal.reject(MediaPreviewItem.LoadError.unknown)
                    return
                }
                self.internalThumbnail = image
                seal.fulfill(image)
            }
        }
    }
    
    public var item: Promise<PreviewType> {
        Promise<Void>().then(on: itemQueue, flags: [.barrier]) { () -> Promise<PreviewType> in
            if let transcodedItem = self.transcodedItem {
                return Promise { $0.fulfill(transcodedItem) }
            }
            
            return self.internalOriginalAsset.then { (asset: AVAsset) -> Promise<URL> in
                let outputURL = MediaConverter.getAssetOutputURL()
                guard let exportSession = MediaConverter.getAVAssetExportSession(from: asset, outputURL: outputURL)
                else {
                    return Promise { $0.reject(MediaPreviewItem.LoadError.unknown) }
                }
                return self.convertVideo(exportSession: exportSession)
            }
        }
    }
    
    @available(*, deprecated, message: "item should be used instead")
    open func getTranscodedItem() -> URL? {
        let sema = DispatchSemaphore(value: 0)
        var url: URL?
        _ = item.done(on: DispatchQueue.global()) { newURL in
            url = newURL
            sema.signal()
        }
        sema.wait()
        return url
    }
    
    override open func getAccessibilityDescription() -> String? {
        let text = #localize("video")
        return text
    }
    
    open func getOriginalItem() -> URL? {
        itemURL
    }
    
    override func freeMemory() {
        video = nil
    }
    
    // MARK: Private functions
    
    private func convertVideo(exportSession: AVAssetExportSession) -> Promise<URL> {
        Promise { seal in
            autoreleasepool {
                isConverting = true
                MediaConverter.convertVideo(with: exportSession) { url in
                    guard let url else {
                        seal.reject(MediaPreviewItem.LoadError.unknown)
                        return
                    }
                    
                    self.transcodedItem = url
                    self.isConverted = true
                    self.isConverting = false
                    self.transcodeSema.signal()
                    
                    seal.fulfill(url)
                } onError: { error in
                    guard let error else {
                        seal.reject(MediaPreviewItem.LoadError.unknown)
                        return
                    }
                    seal.reject(error)
                }
            }
        }
    }
}
