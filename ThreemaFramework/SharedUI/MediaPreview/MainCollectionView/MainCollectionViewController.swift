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
import UIKit

private let imageReuseIdentifier = "ImagePreviewCell"
private let videoReuseIdentifier = "VideoPreviewCell"
private let documentReuseIdentifier = "DocumentPreviewCell"

class MainCollectionViewController: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum MainCollectionViewControllerError: Error {
        case ImageConversionFailed
    }
    
    var delegate: MediaPreviewViewController
    
    init(delegate: MediaPreviewViewController) {
        self.delegate = delegate
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        delegate.mediaData.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        0.0
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        0.0
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = min(collectionView.frame.width, UIScreen.main.bounds.width)
        let size = CGSize(width: width, height: collectionView.frame.height)
        return size
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        var cell: UICollectionViewCell?
        if delegate.mediaData[indexPath.item] is VideoPreviewItem {
            cell = prepareVideoItem(indexPath: indexPath, collectionView: collectionView)
        }
        else if delegate.mediaData[indexPath.item] is ImagePreviewItem {
            cell = prepareImageCell(indexPath: indexPath, collectionView: collectionView)
        }
        else if delegate.mediaData[indexPath.item] is DocumentPreviewItem {
            cell = prepareDocumentCell(indexPath: indexPath, collectionView: collectionView)
        }
        else {
            let err = "Unknown item type"
            DDLogError(err)
            fatalError(err)
        }
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let indexPath = delegate.getCurrentlyVisibleItem() else {
            return
        }
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? ImagePreviewCollectionViewCell else {
            return
        }
        cell.scrollView.setZoomScale(cell.scrollView.minimumZoomScale, animated: true)
    }
    
    var lastContentOffset: CGFloat = 0.0
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset.x
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let section = delegate.currentItem.section
        let size = delegate.largeCollectionView.frame.width
        let items = scrollView.contentOffset.x / size
        
        delegate.currentItem = IndexPath(item: Int(items), section: section)
        
        delegate.updateSelection()
    }
    
    func prepareDocumentCell(indexPath: IndexPath, collectionView: UICollectionView) -> DocumentPreviewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: documentReuseIdentifier,
            for: indexPath
        ) as! DocumentPreviewCell
        cell.indexPath = indexPath
        cell.parent = delegate
        
        DispatchQueue.main.async {
            cell.addAccessibilityLabels()
            cell.showLoadingScreen()
        }
        DispatchQueue.main.async {
            if cell.indexPath == indexPath {
                guard let item = self.delegate.mediaData[indexPath.item] as? DocumentPreviewItem else {
                    return
                }
                cell.loadDocument(item)
            }
        }
        
        return cell
    }
    
    func prepareImageCell(indexPath: IndexPath, collectionView: UICollectionView) -> ImagePreviewCollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(
                withReuseIdentifier: imageReuseIdentifier,
                for: indexPath
            ) as! ImagePreviewCollectionViewCell
        cell.indexPath = indexPath
        
        cell.setColors()
        cell.addAccessibilityLabels()
        cell.showLoadingScreen()
        
        guard let item = delegate.mediaData[indexPath.item] as? ImagePreviewItem else {
            fatalError("Cannot display an ImageCell for a non-image item")
        }
        
        if item.isGIF {
            handleGifItem(item: item, cell: cell)
        }
        else {
            if delegate.memoryConstrained {
                handleMemoryConstrainedImageItem(item: item, cell: cell)
            }
            else {
                handleImageItem(item: item, cell: cell)
            }
        }
        return cell
    }
    
    private func handleMemoryConstrainedImageItem(item: ImagePreviewItem, cell: ImagePreviewCollectionViewCell) {
        item.previewImage.then { image in
            self.convertThumbnail(thumbnail: image)
        }.done { imageData in
            self.updateImageCell(data: imageData, cell: cell)
        }.catch { error in
            DDLogError("An error occured: \(error)")
            if let error = error as? MainCollectionViewControllerError {
                switch error {
                case .ImageConversionFailed:
                    cell.handleError()
                }
            }
            
            if let error = error as? MediaPreviewItem.LoadError {
                switch error {
                case .memoryConstrained:
                    cell.cannotPreview()
                case .unknown, .osNotSupported, .notAvailable:
                    cell.handleError()
                }
            }
        }
    }
    
    private func handleImageItem(item: ImagePreviewItem, cell: ImagePreviewCollectionViewCell) {
        item.item.done { imageData in
            guard let image = UIImage(data: imageData) else {
                return
            }
            cell.updateImageTo(image: image)
        }.catch { error in
            DDLogError("An error occured: \(error)")
            cell.handleError()
        }
    }
    
    private func handleGifItem(item: ImagePreviewItem, cell: ImagePreviewCollectionViewCell) {
        item.item.done { imageData in
            self.updateImageCell(data: imageData, cell: cell)
        }.catch { error in
            DDLogError("An error occured: \(error)")
            cell.handleError()
        }
    }
    
    private func convertThumbnail(thumbnail: UIImage) -> Promise<Data> {
        Promise { seal in
            guard let convertedThumbnail = MediaConverter.jpegRepresentation(for: thumbnail) else {
                seal.reject(MainCollectionViewControllerError.ImageConversionFailed)
                return
            }
            seal.resolve(convertedThumbnail, nil)
        }
    }
    
    func updateImageCell(data: Data, cell: ImagePreviewCollectionViewCell) {
        guard let image = UIImage(data: data) else {
            return
        }
        cell.updateImageTo(image: image)
    }
    
    func prepareVideoItem(indexPath: IndexPath, collectionView: UICollectionView) -> VideoImageCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: videoReuseIdentifier,
            for: indexPath
        ) as! VideoImageCell
        cell.indexPath = indexPath
        
        cell.addAccessibilityLabels()
        cell.showLoadingScreen()
        
        let videoItem = delegate.mediaData[indexPath.item] as! VideoPreviewItem
        videoItem.item.done { url in
            let asset: AVAsset = AVURLAsset(url: url)
            
            if cell.indexPath != indexPath {
                return
            }
            cell.updateVideoWithAsset(asset: asset)
        }.catch { error in
            DDLogError("An error occured: \(error)")
            cell.handleError()
        }
        return cell
    }
}