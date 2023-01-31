//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

/// Default implementation of BlobData for `thumbnailState` and `dataState`
///
/// This an approximation of the information `BlobData` provides to the states of `BlobState` we'd love to observe. All information was collected from state handling
/// in the existing code.
public extension BlobData {
    
    // Note: This implementation only decides on states based on the information available in `BlobData`. Thus we cannot
    //       differentiate if a certain implementation of `BlobData` has a more nuanced view on these states (e.g. a
    //       message type might require a thumbnail). Maybe we want to change that in the future by allowing overrides
    //       of this "default" implementation.
    
    // MARK: - Thumbnail state
    
    /// The state of the thumbnail
    ///
    /// Please note that certain states cannot be reached at this point.
    /// - Incoming: `downloading`, `processing` & `noData(deleted)`
    /// - Outgoing: `noData(deleted)` & `fatalError`
    var thumbnailState: BlobState {
        if !blobIsOutgoing() {
            return .incoming(incomingThumbnailState)
        }
        else {
            return .outgoing(outgoingThumbnailState)
        }
    }
    
    // This only supports: remote, processed and fatalError
    // (i.e. downloading, processing and deleted are note supported)
    private var incomingThumbnailState: IncomingBlobState {
        if blobGetThumbnail() != nil {
            return .processed
        }
        
        // We have no local thumbnail...
        
        if blobGetThumbnailID() == nil {
            // There is no thumbnail to download (e.g. for a documents such as a PDF)
            // Alternatively it might have been deleted by the user...
            return .noData(.noThumbnail)
        }
        
        // There is only one encryption key for both blobs
        if blobGetEncryptionKey() == nil {
            return .fatalError(.noEncryptionKey)
        }
        
        return .remote(error: nil)
    }
    
    // Similar to `outgoingDataState` as both are uploaded in the same go (`BlobMessageSender`)
    // delete state is not supported and there is no fatalError
    private var outgoingThumbnailState: OutgoingBlobState {
        guard blobGetThumbnailID() == nil else {
            return .remote
        }
        
        // We have no thumbnail blob ID...
        
        guard blobGetThumbnail() != nil else {
            return .noData(.noThumbnail)
        }
        
        // We have a local thumbnail...
        
        // We expect the error to be reset whenever a new upload is initiated
        if !blobGetError(), blobGetProgress() != nil {
            return .uploading
        }
        
        // This error might not be correctly set if app was terminated while uploading.
        // This will be resolved in `BlobManager`
        if blobGetError() {
            return .pendingUpload(error: .uploadFailed)
        }
        
        // This might be the not persisted error
        return .pendingUpload(error: .uploadFailed)
    }
    
    // MARK: - Data state
    
    /// The state of the data
    ///
    /// Please note that certain states cannot be reached at this point.
    /// - Incoming: `noData(.noThumbnail)`
    /// - Outgoing: `noData(.noThumbnail)`, `fatalError`
    var dataState: BlobState {
        if !blobIsOutgoing() {
            return .incoming(incomingDataState)
        }
        else {
            return .outgoing(outgoingDataState)
        }
    }
    
    private var incomingDataState: IncomingBlobState {
        if blobGet() != nil {
            return .processed
        }
        
        // We have no local data...
        
        // We expect the error to be reset whenever a new download is initiated
        if !blobGetError(), let progress = blobGetProgress() {
            if progress.floatValue < 1 {
                return .downloading
            }
            else {
                return .processing
            }
        }
        
        if blobGetEncryptionKey() == nil {
            return .fatalError(.noEncryptionKey)
        }
        
        if blobGetError() {
            return .remote(error: .downloadFailed) // or (less likely) fatalError
        }
        
        if blobGetID() == nil {
            // Blob id is set to `nil` when media is deleted (see `EntityDestroyer`)
            return .noData(.deleted)
            // or maybe .fatalError media_file_not_found
        }
        
        return .remote(error: nil)
    }
    
    // So far this has no fatalError
    private var outgoingDataState: OutgoingBlobState {
        guard blobGetID() == nil else {
            return .remote
        }
        
        // We have no blob ID...
                
        // We expect the error to be reset whenever a new upload is initiated
        if !blobGetError(), blobGetProgress() != nil {
            return .uploading
        }
        
        // This error might not be correctly set if app was terminated while uploading.
        // This will be resolved in `BlobManager`
        if blobGetError() {
            return .pendingUpload(error: .uploadFailed)
        }
        
        // This might be the not persisted error
        if blobGet() != nil {
            return .pendingUpload(error: .uploadFailed)
        }
        else {
            // Should we use more information for to decide on this?
            return .noData(.deleted) // this might also be a fatal error as there was never something to upload
        }
    }
}
