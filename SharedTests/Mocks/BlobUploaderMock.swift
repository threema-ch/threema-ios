import Foundation
import PromiseKit
@testable import ThreemaFramework

final class BlobUploaderMock: BlobUploaderProtocol {

    enum BlobUploaderMockError: Error {
        case noBlobID
    }

    private var blobIDs = [Data]()

    convenience init(blobIDs: [Data]) {
        self.init()
        self.blobIDs = blobIDs
    }

    func upload(data: Data, origin: BlobOrigin, setPersistParam: Bool) -> Promise<Data> {
        Promise { seal in
            guard !blobIDs.isEmpty else {
                seal.reject(BlobUploaderMockError.noBlobID)
                return
            }
            seal.fulfill(blobIDs.removeFirst())
        }
    }
}
