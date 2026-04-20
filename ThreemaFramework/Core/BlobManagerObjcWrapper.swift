import CocoaLumberjackSwift
import Foundation

@objc public enum BlobManagerObjCResult: Int {
    case uploaded
    case downloaded
    case inProgress
    case failed
}

extension BlobManagerResult {
    fileprivate var objCResult: BlobManagerObjCResult {
        switch self {
        case .uploaded:
            .uploaded
        case .downloaded:
            .downloaded
        case .inProgress:
            .inProgress
        case .failed:
            .failed
        }
    }
}

/// Wraps the BlobManager to make it usable in Obj-C code, should only be used when new chat view is active
@available(swift, obsoleted: 1.0, renamed: "BlobManager", message: "Only use from Objective-C")
public final class BlobManagerObjCWrapper: NSObject {
    
    /// Start automatic download of blobs in passed object
    /// - Parameter messageID: NSManagedObjectID of message to be synced
    @objc public func autoSyncBlobs(for messageID: NSManagedObjectID?) {
        Task {
            guard let messageID else {
                DDLogError("ObjectID of conversation to create blob message for was nil.")
                return
            }
            
            await BlobManager.shared.autoSyncBlobs(for: messageID)
        }
    }
    
    /// Start up- or download of blobs in passed object
    /// - Parameter messageID: NSManagedObjectID of message to be synced
    @objc public func syncBlobs(
        for messageID: NSManagedObjectID?,
        onCompletion: @escaping (BlobManagerObjCResult) -> Void
    ) {
        Task {
            guard let messageID else {
                DDLogError("ObjectID of conversation to create blob message for was nil.")
                return
            }
            
            let result = await BlobManager.shared.syncBlobs(for: messageID)
            Task { @MainActor in
                onCompletion(result.objCResult)
            }
        }
    }
 
    /// Checks the non isolated state tracker if there are any active blob syncs. Might not return the correct value
    /// since it is not handled in actor isolation.
    /// - Returns: `True` if there are probably some active syncs.
    @objc public func hasActiveSyncs() -> Bool {
        BlobManager.shared.hasActiveSyncs()
    }
}
