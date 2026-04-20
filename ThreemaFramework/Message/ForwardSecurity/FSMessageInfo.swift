import Foundation

/// FS info of a processed incoming message
///
/// Helper to pass FS info from `ForwardSecurityMessageProcessor` to `TaskExecutionReceiveMessage` through
/// `MessageProcessor` written in Objective-C
class FSMessageInfo {
    
    /// Session used to process the incoming FS message
    let session: DHSession
    
    /// Returns `true` if versions changed, `false` otherwise
    let updateVersionsIfNeeded: () -> Bool
    
    init(session: DHSession, updateVersionsIfNeeded: @escaping () -> Bool) {
        self.session = session
        self.updateVersionsIfNeeded = updateVersionsIfNeeded
    }
}
