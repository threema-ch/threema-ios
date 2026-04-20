import Foundation

public enum BlobManagerResult: Sendable {
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
    case noPersistParam
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
