import Foundation
import ThreemaEssentials
import ThreemaFramework

final class GroupPhotoSenderMock: NSObject, GroupPhotoSenderProtocol {
    
    let delay: Double
    
    let blobID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
    let encryptionKey: Data = BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
    
    init(delay: Double = 0) {
        self.delay = delay
        super.init()
    }
    
    func start(
        withImageData imageData: Data?,
        isNoteGroup: Bool,
        onCompletion: @escaping ((Data?, Data?) -> Void),
        onError: (Error) -> Void
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            onCompletion(self.blobID, self.encryptionKey)
        }
    }
}
