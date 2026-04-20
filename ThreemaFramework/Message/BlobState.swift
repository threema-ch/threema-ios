import Foundation

/// State of a blob
///
/// A blob can be incoming or outgoing.
public enum BlobState: CustomStringConvertible, Equatable {
    /// Blob that could be or is downloaded
    case incoming(IncomingBlobState)
    /// Blob that was or needs to be uploaded
    case outgoing(OutgoingBlobState)
    
    public var description: String {
        switch self {
        case let .incoming(incomingBlobState):
            "Incoming: \(incomingBlobState)"
        case let .outgoing(outgoingBlobState):
            "Outgoing: \(outgoingBlobState)"
        }
    }
}

/// State of an incoming blob
public enum IncomingBlobState: CustomStringConvertible, Equatable {
    
    /// On the server. If download failed an `error` should be reported.
    case remote(error: BlobStateError?)
    /// Blob is being downloaded
    case downloading // Provide progress?
    /// Blob is processed (it cannot be displayed at this time)
    case processing // Needed for decrypting or resizing? Or is this just part of downloading?
    /// Blob is ready for display (downloaded and processed)
    case processed
    /// There is no blob data, but not because of an error
    case noData(BlobStateNoDataReason)
    /// Blob cannot be downloaded
    case fatalError(BlobStateError)
    
    public var description: String {
        switch self {
        case let .remote(error: error):
            "remote \(String(describing: error))"
        case .downloading:
            "downloading"
        case .processing:
            "processing"
        case .processed:
            "processed"
        case let .noData(reason):
            "noData \(reason)"
        case let .fatalError(error):
            "fatalError \(error)"
        }
    }
}

/// State of an outgoing blob
public enum OutgoingBlobState: CustomStringConvertible, Equatable {
    // TODO: Maybe add processing states (pendingProcessing & processing) in the future

    /// Blob is waiting for download (for reflected outgoing file message). If download failed an `error` should be
    /// reported.
    case pendingDownload(error: BlobStateError?)
    /// Blob is downloading (for reflected outgoing file message).
    case downloading
    /// Blob is waiting for upload. If upload failed an `error` should be reported.
    case pendingUpload(error: BlobStateError?)
    /// Blob is uploading
    case uploading // Provide progress?
    /// Blob is (/was) on the server
    case remote
    /// There is no blob data, but not because of an error
    case noData(BlobStateNoDataReason)
    /// Blob is in a non-recoverable state
    case fatalError(BlobStateError)
        
    public var description: String {
        switch self {
        case .pendingDownload:
            "pendingDownload"
        case .downloading:
            "downloading"
        case let .pendingUpload(error: error):
            "pendingUpload \(String(describing: error))"
        case .uploading:
            "uploading"
        case .remote:
            "remote"
        case let .noData(reason):
            "noData \(reason)"
        case let .fatalError(error):
            "fatalError \(error)"
        }
    }
}

/// Why is there no data?
public enum BlobStateNoDataReason {
    /// Blob was locally deleted by user
    case deleted
    /// Blob is a thumbnail that doesn't exist
    case noThumbnail
}

/// Error for `IncomingBlobState` or `OutgoingBlobState`
public enum BlobStateError: Error {
    // Incoming
    case noEncryptionKey
    case downloadFailed
    
    // Outgoing
    case uploadFailed
}
