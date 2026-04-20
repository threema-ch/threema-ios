import FileUtility

@objc public final class FileUtilityObjCSetter: NSObject {
    @objc public static func setInitialFileUtility() {
        if FileUtility.shared == nil {
            FileUtility.updateSharedInstance(
                with: CrashingFileUtilityRemoteSecretDecorator(
                    wrapped: FileUtility(),
                    whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
                )
            )
        }
    }

    @objc public static func setRunningPreviewsFileUtility() {
        FileUtility.updateSharedInstance(
            with: FileUtilityNull()
        )
    }
}
