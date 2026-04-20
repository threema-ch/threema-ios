import Foundation

/// Provides the public attributes to access the information and data from data containing message types.
@objc public protocol BlobData {
    var blobIdentifier: Data? { get set }
    var blobThumbnailIdentifier: Data? { get set }
    var blobData: Data? { get set }
    var blobThumbnail: Data? { get set }
    var blobIsOutgoing: Bool { get }
    var blobEncryptionKey: Data? { get }
    // TODO: IOS-3057: Replace with the actual UTTypeIdentifier
    var blobUTTypeIdentifier: String? { get }
    var blobSize: Int { get }
    var blobOrigin: BlobOrigin { get set }
    var blobProgress: NSNumber? { get set }
    var blobError: Bool { get set }
    var blobFilename: String? { get }
    var blobExportFilename: String { get }
    var deletedAt: Date? { get }
    var isPersistingBlob: Bool { get }
}
