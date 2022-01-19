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

import UIKit
import CocoaLumberjackSwift

private let imageReuseIdentifier = "ImagePreviewCell"
private let videoReuseIdentifier = "VideoPreviewCell"
private let documentReuseIdentifier = "DocumentPreviewCell"

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
        let width = min(collectionView.frame.width, UIScreen.main.bounds.width)
        let size = CGSize(width: width, height: collectionView.frame.height)
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell : UICollectionViewCell?
        if self.delegate.mediaData[indexPath.item] is VideoPreviewItem {
            cell = prepareVideoItem(indexPath: indexPath, collectionView: collectionView)
        } else if self.delegate.mediaData[indexPath.item] is ImagePreviewItem {
            cell = prepareImageCell(indexPath: indexPath, collectionView: collectionView)
        } else if self.delegate.mediaData[indexPath.item] is DocumentPreviewItem {
            cell = prepareDocumentCell(indexPath: indexPath, collectionView: collectionView)
        } else {
            let err = "Unknown item type"
            DDLogError(err)
            fatalError(err)
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
    
    func prepareDocumentCell(indexPath : IndexPath, collectionView : UICollectionView) -> DocumentPreviewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: documentReuseIdentifier, for: indexPath) as! DocumentPreviewCell
        cell.indexPath = indexPath
        cell.parent = self.delegate
        
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
    
    func prepareImageCell(indexPath : IndexPath, collectionView : UICollectionView) -> ImagePreviewCollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: imageReuseIdentifier, for: indexPath) as! ImagePreviewCollectionViewCell
        cell.indexPath = indexPath
        
        DispatchQueue.main.async {
            cell.setColors()
            cell.addAccessibilityLabels()
            cell.showLoadingScreen()
        }
        
        self.delegate.mediaFetchQueue.async {
            guard let item = self.delegate.mediaData[indexPath.item] as? ImagePreviewItem else {
                return
            }
            
            guard var data = item.getItem() else {
                DDLogError("Could not get item to preview")
                return
            }
            
            DispatchQueue.main.async {
                if cell.indexPath != indexPath {
                    return
                }
                
                if UTIConverter.isGifMimeType(UTIConverter.mimeType(fromUTI: item.uti!)) {
                    cell.updateImageTo(data: data)
                } else {
                    if self.delegate.memoryConstrained {
                        data = MediaConverter.jpegRepresentation(for: item.getThumbnail()!)!
                    }
                    self.updateImageCell(data: data, cell: cell)
                }
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
            guard let url = videoItem.getItem() else {
                DispatchQueue.main.async {
                    cell.loadingVideoText.text = BundleUtil.localizedString(forKey:"loading_video_failed")
                    cell.loadingVideoText.isHidden = false
                }
                return
            }
            
            let asset: AVAsset = AVURLAsset(url: url)
            
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
