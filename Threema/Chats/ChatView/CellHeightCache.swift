//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

/// Cache the cell hight and  estimated cell hight
final class CellHeightCache {
    
    //  MARK: - Properties

    private var cellHeightCache = [NSManagedObjectID: CGFloat]()
    private var estimatedCellHeightCache = [NSManagedObjectID: CGFloat]()
    
    // MARK: - Height
    
    /// Adds the height of a cell to the cache
    /// - Parameters:
    ///   - height: Height of cell
    ///   - objectID: NSManagedObjectID of cell
    func storeCellHeight(_ height: CGFloat, for objectID: NSManagedObjectID) {
        cellHeightCache[objectID] = height
    }
    
    /// Retrieves the cell height from cache
    /// - Parameter objectID: NSManagedObjectID of cell
    /// - Returns: Height of cell if one can be found, else nil
    func cellHeight(for objectID: NSManagedObjectID) -> CGFloat? {
        cellHeightCache[objectID]
    }
    
    // MARK: - Estimated height
    
    /// Adds the estimated height of a cell to the cache
    /// - Parameters:
    ///   - estimatedHeight: Estimated height of cell
    ///   - objectID: NSManagedObjectID of cell
    func storeEstimatedCellHeight(_ estimatedHeight: CGFloat, for objectID: NSManagedObjectID) {
        estimatedCellHeightCache[objectID] = estimatedHeight
    }
    
    /// Retrieves the estimated cell height from cache
    /// - Parameter objectID: NSManagedObjectID of cell
    /// - Returns: Estimated height of cell if one can be found, else nil
    func estimatedCellHeight(for objectID: NSManagedObjectID) -> CGFloat? {
        estimatedCellHeightCache[objectID]
    }
    
    // MARK: - Clear
    
    /// Clears all caches
    func clear() {
        cellHeightCache.removeAll()
        estimatedCellHeightCache.removeAll()
    }
    
    /// Clears all caches for a given object ID
    /// - Parameter objectID: NSManagedObjectID of cell
    func clearCellHeightCache(for objectID: NSManagedObjectID) {
        cellHeightCache.removeValue(forKey: objectID)
        estimatedCellHeightCache.removeValue(forKey: objectID)
    }
}
