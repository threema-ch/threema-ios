//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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

class ThumbnailCollectionViewController: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    var parent: MediaPreviewViewController?

    
    let mediaFetchQueue = DispatchQueue(label: "MediaDataFetchQueue",
                                        qos: .userInitiated,
                                        attributes: .concurrent,
                                        autoreleaseFrequency: .inherit,
                                        target: nil)
    
    private let reuseIdentifier = "thumbnailCell"
    private let collectionViewInsets : CGFloat = 10
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return parent?.mediaData.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 5.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let collectionViewHeight = collectionView.frame.height
        let width = collectionViewHeight - collectionViewInsets
        let height = collectionViewHeight - collectionViewInsets
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ThumbnailCollectionViewCell
        cell.startLoading()
        
        cell.identifier = indexPath
        
        self.mediaFetchQueue.async {
            self.parent?.mediaData[indexPath.item].getThumbnail(onCompletion: { image in
                self.imageHandler(image: image, cell : cell, indexPath: indexPath)
            })
        }
        return cell
    }
    
    func imageHandler(image : UIImage, cell : ThumbnailCollectionViewCell, indexPath : IndexPath) {
        if cell.identifier != indexPath {
            // Cell has been reused do not update image
            return
        }
        DispatchQueue.main.async {
            cell.loadImage(image: image)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        parent!.largeCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        parent!.updateTextForIndex(indexPath: indexPath, animated: true)
        parent!.currentItem = indexPath
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
    }
    
    func removeItem(at indexPath: IndexPath) {
        _ = parent?.mediaData.remove(at: indexPath.item)
        parent?.largeCollectionView.reloadData()
        parent?.updateSelection()
    }
    
    func insertItem(_ item: MediaPreviewItem, at indexPath: IndexPath) {
        parent?.mediaData.insert(item, at: indexPath.item)
        parent?.largeCollectionView.reloadData()
        parent?.updateSelection()
    }
}

@available(iOS 11.0, *)
extension ThumbnailCollectionViewController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        
        let cell = collectionView.cellForItem(at: indexPath) as! ThumbnailCollectionViewCell
        guard let image = cell.imageView.image else {
            return []
        }
        
        let item = NSItemProvider(object: image)
        let dragItem = UIDragItem(itemProvider: item)
        return [dragItem]
    }
}

@available(iOS 11.0, *)
extension ThumbnailCollectionViewController: UICollectionViewDropDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?)
    -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(
            operation: .move,
            intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            return
        }
        
        coordinator.items.forEach { dropItem in
            guard let sourceIndexPath = dropItem.sourceIndexPath else {
                return
            }
            
            collectionView.performBatchUpdates({
                let item = parent?.mediaData[sourceIndexPath.item]
                removeItem(at: sourceIndexPath)
                insertItem(item!, at: destinationIndexPath)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            }, completion: { _ in
                coordinator.drop(dropItem.dragItem,
                                 toItemAt: destinationIndexPath)
            })

            if self.parent?.currentItem == sourceIndexPath {
                self.parent?.currentItem = destinationIndexPath
            } else {
                if destinationIndexPath < self.parent!.currentItem && sourceIndexPath > self.parent!.currentItem {
                    self.parent?.currentItem = IndexPath(item: min(self.parent!.currentItem.item + 1, self.parent!.mediaData.count - 1), section: 0)
                } else if destinationIndexPath > self.parent!.currentItem && sourceIndexPath < self.parent!.currentItem {
                    self.parent?.currentItem = IndexPath(item: max(self.parent!.currentItem.item - 1, 0), section: 0)
                } else if destinationIndexPath == self.parent!.currentItem {
                    if sourceIndexPath < self.parent!.currentItem {
                        self.parent?.currentItem = IndexPath(item: max(self.parent!.currentItem.item - 1, 0), section: 0)
                    } else {
                        self.parent?.currentItem = IndexPath(item: min(self.parent!.currentItem.item + 1, self.parent!.mediaData.count - 1), section: 0)
                        
                    }
                }
            }
            
            self.parent?.largeCollectionView.selectItem(at: self.parent?.currentItem, animated: true, scrollPosition: .centeredHorizontally)
            self.parent?.updateSelection()
            self.parent?.shouldScrollTo(indexPath: self.parent!.currentItem)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return true
    }
}
