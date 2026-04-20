import Foundation

extension BlobData {
    
    /// Can the media be forwarded, shared, saved etc.
    public var isDataAvailable: Bool {
        switch blobDisplayState {
        case .processed, .pending, .uploading, .uploaded, .sendingError:
            true
        case .remote, .downloading, .fileNotFound, .dataDeleted:
            false
        }
    }
}
