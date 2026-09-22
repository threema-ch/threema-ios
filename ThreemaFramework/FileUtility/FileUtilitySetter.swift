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
