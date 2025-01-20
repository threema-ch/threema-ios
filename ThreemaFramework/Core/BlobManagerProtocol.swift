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

public enum BlobManagerResult {
    case uploaded
    case downloaded
    case inProgress
    
    /// Failed sync
    ///
    /// Only use for non-throwing functions
    case failed
}

public enum BlobManagerError: Error {
    case noID
    case noData
    case unableToLoadMessageAsBlobData
    case noEncryptionKey
    case alreadySyncing
    case stateMismatch
    case cryptographyFailed
    case uploadFailed
    case noOrigin
    case markDoneFailed
    case noteGroupNeedsNoSync
    case notConnected
}

/// Defines the public functions used in BlobManager.swift
public protocol BlobManagerProtocol {
    /// Start automatic download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    func autoSyncBlobs(for objectID: NSManagedObjectID) async
    
    /// Start up- or download of blobs in passed object
    ///
    /// If you want to upload and send a blob message use
    /// `MessageSender.sendBlobMessage(for:in:correlationID:webRequestID)`
    ///
    /// - Parameter objectID: Object to sync blobs for
    func syncBlobs(for objectID: NSManagedObjectID) async -> BlobManagerResult
    
    /// Same as `syncBlobs(for:)` but throws an error if there was any
    ///
    /// Mostly used for testing
    ///
    /// - Parameter objectID: Object to sync blobs for
    func syncBlobsThrows(for objectID: NSManagedObjectID) async throws -> BlobManagerResult
    
    /// Cancel up- or download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    func cancelBlobsSync(for objectID: NSManagedObjectID) async
}
