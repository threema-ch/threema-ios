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

class MediaPreviewCarouselAccessibilityElement : UIAccessibilityElement {
    var currentMediaItem: IndexPath?
    
    init(accessibilityContainer: Any, currentMediaItem : IndexPath?) {
        super.init(accessibilityContainer : accessibilityContainer)
        self.currentMediaItem = currentMediaItem
    }
    
    override var accessibilityLabel: String? {
        get {
            let text = BundleUtil.localizedString(forKey:"selected_media_list")
            return text
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
    
    override var accessibilityValue: String? {
        get {
            let text = String(format: BundleUtil.localizedString(forKey:"media_item_of"), "\(currentMediaItem!.item + 1)", " \(getTotalItems())")
            
            guard let containerView = accessibilityContainer as? MediaPreviewCarouselContainerView else {
                return text
            }
            
            guard let delegate = containerView.delegate else {
                return text
            }
            
            guard let index = self.currentMediaItem else {
                return text
            }
            
            guard let description = delegate.mediaData[index.item].getAccessiblityDescription() else {
                return text
            }
            
            return text + description
        }
        set {
            super.accessibilityValue = newValue
        }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return UIAccessibilityTraits.adjustable
        }
        set {
            super.accessibilityTraits = newValue
        }
    }
    
    func getTotalItems() -> Int {
        
        guard let containerView = accessibilityContainer as? MediaPreviewCarouselContainerView else {
            return 0
        }
        
        guard let delegate = containerView.delegate else {
            return 0
        }
        
        guard let collectionView = delegate.largeCollectionView else {
            return 0
        }
        
        guard self.currentMediaItem != nil else {
            return 0
        }
        
        return collectionView.numberOfItems(inSection: 0)
    }
    
    func accessibilityScrollCollectionView(forwards: Bool) -> Bool {
        guard let containerView = accessibilityContainer as? MediaPreviewCarouselContainerView else {
            return false
        }
        
        guard let delegate = containerView.delegate else {
            return false
        }
        
        guard let collectionView = delegate.largeCollectionView else {
            return false
        }
        
        guard let index = self.currentMediaItem else {
            return false
        }
        
        if forwards {
            if collectionView.numberOfItems(inSection: 0) - 1 < index.item + 1 {
                return false
            }
            let newIndex =  IndexPath.init(item: index.item + 1, section: 0)
            delegate.shouldScrollTo(indexPath: newIndex)
            self.currentMediaItem = newIndex
        } else {
            if index.item - 1 < 0 {
                return false
            }
            let newIndex =  IndexPath.init(item: index.item - 1, section: 0)
            delegate.shouldScrollTo(indexPath: newIndex)
            self.currentMediaItem = newIndex
        }
        
        return true
    }
    
    override func accessibilityIncrement() {
        _ = accessibilityScrollCollectionView(forwards: true)
    }
    
    override func accessibilityDecrement() {
        _ = accessibilityScrollCollectionView(forwards: false)
    }
    
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .left {
            return accessibilityScrollCollectionView(forwards: true)
        } else if direction == .right {
            return accessibilityScrollCollectionView(forwards: false)
        }
        return false
    }
}
