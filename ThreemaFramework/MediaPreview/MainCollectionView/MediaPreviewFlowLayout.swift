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

class MediaPreviewFlowLayout: UICollectionViewFlowLayout {
    
    /// Returns the width of the collectionView minus the relevant insets
    /// - Parameter bounds: the bounds of the collectionView
    /// - Returns: Width of a cell in the collectionView
    func cellWidth(bounds: CGRect) -> CGFloat {
        guard let collectionView = collectionView else {
            return 0
        }
        
        let insets = collectionView.contentInset
        let width = bounds.width - insets.left - insets.right
        
        if width < 0 {
            return 0
        } else {
            return width
        }
    }
    
    /// Returns the height of the collectionView minus the relevant insets
    /// - Parameter bounds: the bounds of the collectionView
    /// - Returns: Height of a cell in the collectionView
    func cellHeight(bounds : CGRect) -> CGFloat {
        guard let collectionView = collectionView else {
            return 0
        }
        
        let insets = collectionView.contentInset
        let height = bounds.height - insets.top - insets.bottom
        
        if height < 0 {
            return 0
        } else {
            return height
        }
    }
    
    // Update the estimatedItemSize to the bounds
    func updateEstimatedItemSize(bounds: CGRect) {
        let height = cellHeight(bounds: bounds)
        let width = cellWidth(bounds: bounds)
        
        estimatedItemSize = CGSize(
            width: width,
            height: height
        )
    }
    
    func updateContentOffset(bounds: CGRect) {
        guard let collectionView = self.collectionView?.dataSource as? MainCollectionViewController else {
            return
        }
        
        guard let selection = collectionView.delegate.getCurrentlyVisibleItem() else {
            return
        }
        
        guard let largeCollectionView = collectionView.delegate.largeCollectionView else {
            return
        }
        
        let size = collectionView.collectionView(largeCollectionView, layout: self, sizeForItemAt: selection)
        let xOffset = size.width * CGFloat(selection.item)
        let offset = CGPoint(x: xOffset, y: 0.0)
        self.collectionView?.contentOffset = offset
    }
    
    // Is called whenever the layout is invalid.
    // Either on first display or when the layout is manually invalidated.
    override func prepare() {
        super.prepare()
        
        let bounds = collectionView?.bounds ?? .zero
        updateEstimatedItemSize(bounds: bounds)
        updateContentOffset(bounds: bounds)
    }
    
    // Update the estimated size and the content offset if the screen size  has changed
    // i.e. if the device has been rotated
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let _ = super.shouldInvalidateLayout(forBoundsChange: newBounds)
        
        guard let collectionView = collectionView else {
            return false
        }
        
        let oldSize = collectionView.bounds.size
        if oldSize == newBounds.size {
            return false
        }
        
        updateEstimatedItemSize(bounds: newBounds)
        updateContentOffset(bounds: newBounds)
        
        return true
    }    
}
