//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

/// Used as a central point to keep track of current up- and downloads, and optionally of their progress
actor BlobManagerState {
    
    /// Set containing all objectIDs that are currently being processed
    /// Note: The objectD of a thumbnail and its data is the same, since the processing is done in sequence, this will
    /// not lead to any conflicts
    private var activeObjectIDs = Set<NSManagedObjectID>()

    // We track progress to limit progress updates
    private var objectIDProgress = [NSManagedObjectID: Double]()
    
    // MARK: - General
    
    /// Returns if an objectID is active
    /// - Parameter objectID: ObjectID to be checked
    /// - Returns: True if there is an active objectID, false otherwise
    func isActive(_ objectID: NSManagedObjectID) -> Bool {
        activeObjectIDs.contains(objectID)
    }
    
    /// Adds an active objectID, throws if it is already active
    /// - Parameters:
    ///   - objectID: ObjectID to be kept track of
    func addActiveObjectID(_ objectID: NSManagedObjectID) throws {
        guard !isActive(objectID) else {
            throw BlobManagerError.alreadySyncing
        }
        activeObjectIDs.insert(objectID)
    }
    
    /// Removes the given objectID from the active objectID and from the progress keeper
    /// - Parameter objectID: ObjectID to be removed
    /// - Returns: Bool if the objectID and its progress was removed
    @discardableResult
    func removeActiveObjectIDAndProgress(for objectID: NSManagedObjectID) -> Bool {
        var didRemove = false
        if activeObjectIDs.remove(objectID) != nil {
            objectIDProgress.removeValue(forKey: objectID)
            didRemove = true
        }
        return didRemove
    }
    
    /// Removes the progress for a given objectID if it exists
    /// - Parameter objectID: ObjectID to remove state for
    func removeProgress(for objectID: NSManagedObjectID) {
        objectIDProgress.removeValue(forKey: objectID)
    }
        
    /// Returns the current progress value of an objectID
    /// - Parameter objectID: ObjectID to get the progress for
    /// - Returns: Progress if it exists, nil otherwise
    func progress(for objectID: NSManagedObjectID) -> Double? {
        objectIDProgress[objectID]
    }
    
    /// Sets the provided progress for the given objectID
    /// - Parameters:
    ///   - objectID: ObjectID to set the progress for
    ///   - progress: Progress to be set
    func setProgress(for objectID: NSManagedObjectID, to progress: Double) {
        objectIDProgress[objectID] = progress
    }
    
    /// Checks if there are any active objectIDs
    /// - Returns: True if there are, false otherwise
    func hasActiveObjectIDs() -> Bool {
        !activeObjectIDs.isEmpty
    }
}

/// Used to track if there are active syncs in a non actor isolated context
public class BlobManagerActiveState {
    public var hasActiveSyncs = false
}
