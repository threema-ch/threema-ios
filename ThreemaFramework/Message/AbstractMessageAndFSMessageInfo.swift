import Foundation

/// A helper object to facilitate communication / passing (Swift) objects between `TaskExecutionReceiveMessage`,
/// `MessageProcessor` and `ForwardSecurityMessageProcessor`
class AbstractMessageAndFSMessageInfo: NSObject {
    @objc let message: AbstractMessage?
    @objc let fsMessageInfo: Any? // Must be a FSMessageInfo
    
    @objc init(message: AbstractMessage?, fsMessageInfo: Any?) {
        assert(fsMessageInfo == nil || fsMessageInfo! is FSMessageInfo)
        assert(!(fsMessageInfo != nil && message == nil))
        
        self.message = message
        self.fsMessageInfo = fsMessageInfo
    }
}
