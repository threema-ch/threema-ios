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

class ThumbnailCollectionViewController: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    var parent: MediaPreviewViewController?
    
    private let reuseIdentifier = "thumbnailCell"
    private let collectionViewInsets: CGFloat = 13.0
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return parent?.mediaData.count ?? 0
        }
        if section == 1 {
            guard let parent = parent else {
                return 0
            }
            return parent.disableAdd ? 0 : 1
        }
        if section == 2 {
            guard let parent = parent else {
                return 0
            }
            return parent.conversationDescription == nil ? 0 : 1
        }
        return 0
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sections = 1
        guard let parent = parent else {
            return sections
        }
        if !parent.disableAdd {
            sections = 2
        }
        if parent.conversationDescription != nil {
            sections = 3
        }
        return sections
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        6.0
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
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        if section == 0 {
            return UIEdgeInsets(top: 13, left: 13.0, bottom: 13.0, right: (parent?.disableAdd ?? false) ? 13 : 0)
        }
        if section == 1 {
            return UIEdgeInsets(top: 13, left: 6.0, bottom: 13.0, right: 0)
        }
        return UIEdgeInsets(top: 13, left: 0.0, bottom: 13.0, right: 13)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if indexPath.section == 2 {
            let collectionViewHeight = collectionView.frame.height
            
            let label = ConversationDescriptionCell.descriptionLabel
            label.attributedText = parent?.conversationDescription
            
            let intrinsicWidth = label.intrinsicContentSize.width
            let newWidth = min(1200, intrinsicWidth)
            
            let width: CGFloat = newWidth
            let height = collectionViewHeight - collectionViewInsets * 2
            
            return CGSize(width: width, height: height)
        }
        
        let collectionViewHeight = collectionView.frame.height
        let width = collectionViewHeight - collectionViewInsets * 2
        let height = collectionViewHeight - collectionViewInsets * 2
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "PlusButtonCell",
                for: indexPath
            ) as! PlusButtonCollectionViewCell
            cell.setup()
            return cell
        }
        if indexPath.section == 2 {
            guard let parent = parent else {
                fatalError("Cannot create cell due to missing parent")
            }
            guard let conversationDescription = parent.conversationDescription else {
                fatalError("Cannot create cell due to missing conversation description")
            }
            
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ConversationDescriptionCell",
                for: indexPath
            ) as! ConversationDescriptionCell

            cell.setupCell(conversationDescription: conversationDescription)

            return cell
        }
        
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ThumbnailCollectionViewCell
        cell.startLoading()
        
        cell.identifier = indexPath
        
        guard let parent = parent else {
            return cell
        }
        
        parent.mediaData[indexPath.item].thumbnail.done { image in
            self.imageHandler(image: image, cell: cell, indexPath: indexPath)
        }.catch { _ in
            cell.activityIndicator.hidesWhenStopped = true
            cell.activityIndicator.stopAnimating()
        }
        return cell
    }
    
    func imageHandler(image: UIImage, cell: ThumbnailCollectionViewCell, indexPath: IndexPath) {
        if cell.identifier != indexPath {
            // Cell has been reused do not update image
            return
        }
        DispatchQueue.main.async {
            cell.loadImage(image: image)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            parent!.addButtonPressed()
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        else if indexPath.section == 0 {
            parent!.largeCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            parent!.updateTextForIndex(indexPath: indexPath, animated: true)
            parent!.currentItem = indexPath
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        }
        else {
            DDLogVerbose("No interaction possible on")
        }
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

// MARK: - UICollectionViewDragDelegate

extension ThumbnailCollectionViewController: UICollectionViewDragDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        dragSessionIsRestrictedToDraggingApplication session: UIDragSession
    ) -> Bool {
        true
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        if indexPath.section != 0 {
            return []
        }
        let cell = collectionView.cellForItem(at: indexPath) as! ThumbnailCollectionViewCell
        guard let image = cell.imageView.image else {
            return []
        }
        
        let item = NSItemProvider(object: image)
        let dragItem = UIDragItem(itemProvider: item)
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension ThumbnailCollectionViewController: UICollectionViewDropDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    )
        -> UICollectionViewDropProposal {
        if destinationIndexPath?.section != 0 {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        else {
            return UICollectionViewDropProposal(
                operation: .move,
                intent: .insertAtDestinationIndexPath
            )
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
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
                coordinator.drop(
                    dropItem.dragItem,
                    toItemAt: destinationIndexPath
                )
            })
            
            if self.parent?.currentItem == sourceIndexPath {
                self.parent?.currentItem = destinationIndexPath
            }
            else {
                if destinationIndexPath < self.parent!.currentItem, sourceIndexPath > self.parent!.currentItem {
                    self.parent?.currentItem = IndexPath(
                        item: min(self.parent!.currentItem.item + 1, self.parent!.mediaData.count - 1),
                        section: 0
                    )
                }
                else if destinationIndexPath > self.parent!.currentItem, sourceIndexPath < self.parent!.currentItem {
                    self.parent?.currentItem = IndexPath(item: max(self.parent!.currentItem.item - 1, 0), section: 0)
                }
                else if destinationIndexPath == self.parent!.currentItem {
                    if sourceIndexPath < self.parent!.currentItem {
                        self.parent?.currentItem = IndexPath(
                            item: max(self.parent!.currentItem.item - 1, 0),
                            section: 0
                        )
                    }
                    else {
                        self.parent?.currentItem = IndexPath(
                            item: min(self.parent!.currentItem.item + 1, self.parent!.mediaData.count - 1),
                            section: 0
                        )
                    }
                }
            }
            
            self.parent?.largeCollectionView.selectItem(
                at: self.parent?.currentItem,
                animated: true,
                scrollPosition: .centeredHorizontally
            )
            self.parent?.updateSelection()
            self.parent?.shouldScrollTo(indexPath: self.parent!.currentItem)
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        canHandle session: UIDropSession
    ) -> Bool {
        true
    }
}
