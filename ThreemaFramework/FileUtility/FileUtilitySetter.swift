import FileUtility

public enum FileUtilitySetter {
    public static func setInitialFileUtility() {
        guard FileUtility.shared == nil else {
            return
        }
        
        FileUtility.updateSharedInstance(
            with: CrashingFileUtilityRemoteSecretDecorator(
                wrapped: FileUtility(),
                whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
            )
        )
    }
    
    public static func setRunningPreviewsFileUtility() {
        FileUtility.updateSharedInstance(
            with: FileUtilityNull()
        )
    }
}

@available(
    swift,
    obsoleted: 1.0,
    renamed: "FileUtilityObjCSetter",
    message: "Only use from Objective-C"
)
@objc public class FileUtilityObjCSetter: NSObject {
    @objc public static func setInitialFileUtility() {
        FileUtilitySetter.setInitialFileUtility()
    }

    @objc public static func setRunningPreviewsFileUtility() {
        FileUtilitySetter.setRunningPreviewsFileUtility()
    }
}
