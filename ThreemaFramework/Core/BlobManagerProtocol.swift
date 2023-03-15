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

public enum BlobManagerError: Error {
    case noID
    case noData
    case messageNotFound
    case noEncryptionKey
    case alreadySyncing
    case stateMismatch
    case cryptographyFailed
    case tooBig
    case uploadFailed
    case noOrigin
    case markDoneFailed
    case sendingFailed
}

/// Defines the public functions used in BlobManager.swift
public protocol BlobManagerProtocol {
        
    /// Creates a message for a given URLSenderItem and syncs the blobs of it, and  throws if something goes wrong
    /// - Parameters:
    ///   - item: URLSenderItem
    ///   - conversation: Conversation where message is sent
    ///   - correlationID: Optional String used to identify blobs that are sent together
    ///   - webRequestID: Optional String used to identify the web request
    func createMessageAndSyncBlobs(
        for item: URLSenderItem,
        in conversationID: NSManagedObjectID,
        correlationID: String?,
        webRequestID: String?
    ) async throws
    
    /// Start automatic download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    func autoSyncBlobs(for objectID: NSManagedObjectID) async
    
    /// Start up- or download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    func syncBlobs(for objectID: NSManagedObjectID) async
    
    /// Same as `syncBlobs(for:)` but throws an error if there was any
    ///
    /// Mostly used for testing
    ///
    /// - Parameter objectID: Object to sync blobs for
    func syncBlobsThrows(for objectID: NSManagedObjectID) async throws
    
    /// Cancel up- or download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    func cancelBlobsSync(for objectID: NSManagedObjectID) async
}

public extension BlobManagerProtocol {
    
    func createMessageAndSyncBlobs(
        for item: URLSenderItem,
        in conversationID: NSManagedObjectID,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) async throws {
        try await createMessageAndSyncBlobs(
            for: item,
            in: conversationID,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }
}
