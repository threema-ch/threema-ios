//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

import UIKit

private let imageReuseIdentifier = "ImagePreviewCell"
private let videoReuseIdentifier = "VideoPreviewCell"

class MainCollectionViewController: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var delegate : MediaPreviewViewController
    
    init(delegate : MediaPreviewViewController) {
        self.delegate = delegate
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.delegate.mediaData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell : UICollectionViewCell?
        if self.delegate.mediaData[indexPath.item] is VideoPreviewItem {
            cell = prepareVideoItem(indexPath: indexPath, collectionView: collectionView)
        } else {
            cell = prepareImageCell(indexPath: indexPath, collectionView: collectionView)
        }
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let indexPath  = self.delegate.getCurrentlyVisibleItem()  else {
            return
        }
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? ImagePreviewCollectionViewCell else {
            return
        }
        cell.scrollView.setZoomScale(cell.scrollView.minimumZoomScale, animated: true)
    }
    
    var lastContentOffset : CGFloat = 0.0
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.lastContentOffset = scrollView.contentOffset.x
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        let section = self.delegate.currentItem.section
        
        let size = self.delegate.largeCollectionView.frame.width
        let items = scrollView.contentOffset.x / size
        
        self.delegate.currentItem = IndexPath(item: Int(items), section: section)
        
        self.delegate.updateSelection()
    }
    
    func prepareImageCell(indexPath : IndexPath, collectionView : UICollectionView) -> ImagePreviewCollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: imageReuseIdentifier, for: indexPath) as! ImagePreviewCollectionViewCell
        cell.indexPath = indexPath
        
        DispatchQueue.main.async {
            cell.setColors()
            cell.addAccessibilityLabels()
            cell.showLoadingScreen()
            
            if cell.indexPath != indexPath {
                return
            }
            
            guard let item = self.delegate.mediaData[indexPath.item] as? ImagePreviewItem else {
                return
            }
            
            guard let data = item.getItem() else {
                return
            }
            
            if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: item.uti!)) {
                cell.updateImageTo(data: data)
            } else {
                self.updateImageCell(data: data, cell: cell)
            }
        }
        return cell
    }
    
    func updateImageCell(data : Data, cell : ImagePreviewCollectionViewCell) {
        guard let image = UIImage(data: data) else {
            return
        }
        cell.updateImageTo(image: image)
    }
    
    func prepareVideoItem(indexPath : IndexPath, collectionView : UICollectionView) -> VideoImageCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: videoReuseIdentifier, for: indexPath) as! VideoImageCell
        cell.indexPath = indexPath
        
        cell.addAccessibilityLabels()
        cell.showLoadingScreen()
        
        self.delegate.mediaFetchQueue.async {
            let videoItem = self.delegate.mediaData[indexPath.item] as! VideoPreviewItem
            guard let asset: AVAsset = videoItem.getItem() else {
                cell.loadingVideoText.text = String(format: NSLocalizedString("loading_video_failed", comment: ""))
                cell.loadingVideoText.isHidden = false
                return
            }
            
            DispatchQueue.main.async {
                if cell.indexPath != indexPath {
                    return
                }
                cell.updateVideoWithAsset(asset: asset)
            }
        }
        return cell
    }
    
}
