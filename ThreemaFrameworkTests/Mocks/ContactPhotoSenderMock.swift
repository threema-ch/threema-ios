import ThreemaFramework

final class ContactPhotoSenderMock: NSObject, ContactPhotoSenderProtocol {

    static var numberOfSendProfileRequestCalls = 0
    
    static func sendProfilePictureRequest(_ toIdentity: String) {
        numberOfSendProfileRequestCalls += 1
    }
    
    func sendProfilePicture(message: AbstractMessage) {
        // no-op
    }
    
    func startWithImage(
        toMember toMemberObject: NSObject,
        onCompletion: (() -> Void)?,
        onError: (((any Error)?) -> Void)? = nil
    ) {
        onCompletion?()
    }
}
