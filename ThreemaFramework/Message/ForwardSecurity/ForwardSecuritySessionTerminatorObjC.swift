/// Obj-C wrapper for `ForwardSecuritySessionTerminator`
@available(swift, obsoleted: 1.0, renamed: "ForwardSecuritySessionTerminator", message: "Only use from Objective-C")
class ForwardSecuritySessionTerminatorObjC: NSObject {
    
    /// Terminate all sessions with contact with the reason "disabled by remote"
    ///
    /// - Note: You are responsible that this is called on the correct queue for `contact` and that you save `contact`
    ///         afterwards.
    ///
    /// - Parameters:
    ///   - identity: Identity to terminate sessions for
    ///   - completion: Called on successful termination. Returns `true` if any session was terminated
    ///   - error: Called if termination fails
    @objc static func terminateAllSessionsWithDisabledByRemote(
        for contact: ContactEntity,
        completion: (Bool) -> Void,
        error: (Error) -> Void
    ) {
        do {
            let forwardSecuritySessionTerminator = try ForwardSecuritySessionTerminator()
            
            let result = try forwardSecuritySessionTerminator.terminateAllSessions(
                with: contact,
                cause: .disabledByRemote
            )
            
            completion(result)
        }
        catch let caughtError {
            error(caughtError)
        }
    }
}
