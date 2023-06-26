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
            return "Incoming: \(incomingBlobState)"
        case let .outgoing(outgoingBlobState):
            return "Outgoing: \(outgoingBlobState)"
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
            return "remote \(String(describing: error))"
        case .downloading:
            return "downloading"
        case .processing:
            return "processing"
        case .processed:
            return "processed"
        case let .noData(reason):
            return "noData \(reason)"
        case let .fatalError(error):
            return "fatalError \(error)"
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
            return "pendingDownload"
        case .downloading:
            return "downloading"
        case let .pendingUpload(error: error):
            return "pendingUpload \(String(describing: error))"
        case .uploading:
            return "uploading"
        case .remote:
            return "remote"
        case let .noData(reason):
            return "noData \(reason)"
        case let .fatalError(error):
            return "fatalError \(error)"
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
