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

import CocoaLumberjackSwift
import Foundation

/// Display state for the associated blob(s)
public enum BlobDisplayState: CustomStringConvertible, Equatable {
        
    // TODO: In a future version we might want to display more states like a processing stage or when parts of the upload failed
    
    // Outgoing
    
    /// Blob data ready for upload
    case pending
    /// Blob data is uploading with progress as fraction (0...1)
    case uploading(progress: Float)
    /// Blob is uploaded on server
    case uploaded
    /// An error occurred during the sending of the message
    case sendingError
    
    // Shared
    
    /// Blob data on server
    case remote
    /// Blob data is downloading with progress as fraction (0...1)
    case downloading(progress: Float)
    /// Blob data is downloaded and processed
    case processed // TODO: (IOS-2386) play?
    /// Blob data was deleted
    case dataDeleted
    /// Blob data cannot be found
    case fileNotFound
    
    public var description: String {
        switch self {
        case .remote:
            return "remote"
        case let .downloading(progress: progress):
            return "downloading... (\(progress))"
        case .processed:
            return "processed"
        case .pending:
            return "pending"
        case let .uploading(progress: progress):
            return "uploading... (\(progress))"
        case .uploaded:
            return "uploaded"
        case .sendingError:
            return "sendingError"
        case .dataDeleted:
            return "dataDeleted"
        case .fileNotFound:
            return "fileNotFound"
        }
    }
    
    /// System symbol name for current state if appropriate
    public var symbolName: String? {
        switch self {
        case .remote:
            return "arrow.down"
        case .downloading, .uploading:
            return "stop.fill"
        case .processed, .uploaded:
            return nil
        case .pending, .sendingError:
            return "arrow.clockwise"
        case .dataDeleted:
            return "rectangle.slash.fill"
        case .fileNotFound:
            return "exclamationmark"
        }
    }
    
    /// System symbol name for current state if appropriate
    public var circleFillSymbolName: String? {
        switch self {
        case .remote:
            return "arrow.down.circle.fill"
        case .downloading, .uploading:
            return "stop.circle.fill"
        case .processed, .uploaded:
            return nil
        case .pending, .sendingError:
            return "arrow.clockwise.circle.fill"
        case .dataDeleted:
            return "rectangle.slash.fill"
        case .fileNotFound:
            return "exclamationmark.circle.fill"
        }
    }
}

extension BlobData {
    /// Current display state
    public var blobDisplayState: BlobDisplayState {
        if case let .incoming(incomingThumbnailState) = thumbnailState,
           case let .incoming(incomingDataState) = dataState {
            return incomingBlobDisplayState(for: incomingThumbnailState, and: incomingDataState)
        }
        else if case let .outgoing(outgoingThumbnailState) = thumbnailState,
                case let .outgoing(outgoingDataState) = dataState {
            return outgoingBlobDisplayState(for: outgoingThumbnailState, and: outgoingDataState)
        }
        
        fatalError("One state is incoming and the other outgoing")
    }
    
    /// Helper to log error and abort during debug
    private func error(_ message: String) -> BlobDisplayState {
        DDLogError(message)
        assertionFailure()
        return .fileNotFound
    }
    
    private func incomingBlobDisplayState(
        for incomingThumbnailState: IncomingBlobState,
        and incomingDataState: IncomingBlobState
    ) -> BlobDisplayState {
        switch incomingDataState {
        case .remote:
            switch incomingThumbnailState {
            case .remote, .processed, .noData(.noThumbnail), .fatalError:
                return .remote
            case .noData(.deleted):
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .downloading, .processing:
            switch incomingThumbnailState {
            case .remote, .processed, .noData(.noThumbnail), .fatalError:
                return .downloading(progress: blobProgress?.floatValue ?? 0)
            case .noData(.deleted):
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .processed:
            switch incomingThumbnailState {
            case .remote, .processed, .noData(.noThumbnail), .fatalError:
                return .processed
            case .noData(.deleted):
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .noData(.deleted):
            switch incomingThumbnailState {
            // TODO: Should remote be "ignored"?
            case .remote, .processed, .noData(.noThumbnail), .noData(.deleted), .fatalError:
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .fatalError:
            return .fileNotFound
        case .noData(.noThumbnail):
            return error("No thumbnail state for incoming data state is illegal")
        }
    }
    
    private func outgoingBlobDisplayState(
        for outgoingThumbnailState: OutgoingBlobState,
        and outgoingDataState: OutgoingBlobState
    ) -> BlobDisplayState {
        switch outgoingDataState {
        case .pendingDownload:
            return .remote
        case .downloading:
            return .downloading(progress: blobProgress?.floatValue ?? 0)
        case .pendingUpload:
            switch outgoingThumbnailState {
            case .pendingUpload, .remote, .noData(.noThumbnail):
                return .pending
            case .uploading:
                // In the current implementation of BlobDataState this is not really reachable
                return .uploading(progress: blobProgress?.floatValue ?? 0)
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .uploading:
            switch outgoingThumbnailState {
            case .pendingUpload, .uploading, .remote, .noData(.noThumbnail):
                return .uploading(progress: blobProgress?.floatValue ?? 0)
            case .noData(.deleted):
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .remote:
            switch outgoingThumbnailState {
            case .pendingDownload:
                return .remote
            case .pendingUpload, .remote, .noData(.noThumbnail):
                if blobError {
                    return .sendingError
                }
                return .uploaded
                
            case .uploading:
                return .uploading(progress: blobProgress?.floatValue ?? 0)
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .noData(.deleted):
            switch outgoingThumbnailState {
            case .pendingUpload, .uploading, .remote, .noData(.noThumbnail), .noData(.deleted):
                return .dataDeleted
            default:
                return error("Unknown thumbnail state: \(thumbnailState.description)")
            }
        case .fatalError:
            return error("Fatal error state for outgoing data state is illegal")
        case .noData(.noThumbnail):
            return error("No thumbnail state for outgoing data state is illegal")
        }
    }
}
