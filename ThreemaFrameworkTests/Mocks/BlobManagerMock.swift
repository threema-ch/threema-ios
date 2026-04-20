import Foundation
import XCTest
@testable import ThreemaFramework

final class BlobManagerMock: BlobManagerProtocol {
    
    var syncHandler: (NSManagedObjectID) throws -> BlobManagerResult = { _ in
        .failed
    }
    
    // MARK: BlobManagerProtocol
    
    func autoSyncBlobs(for objectID: NSManagedObjectID) async {
        // no-op
    }
    
    func syncBlobs(for objectID: NSManagedObjectID) async -> BlobManagerResult {
        do {
            return try await syncBlobsThrows(for: objectID)
        }
        catch {
            return .failed
        }
    }
    
    func syncBlobsThrows(for objectID: NSManagedObjectID) async throws -> ThreemaFramework.BlobManagerResult {
        try syncHandler(objectID)
    }
    
    func cancelBlobsSync(for objectID: NSManagedObjectID) async {
        // no-op
    }
}
